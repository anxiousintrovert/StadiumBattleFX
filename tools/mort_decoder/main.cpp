#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#include "MORTDecoder.h"

static void write_u16(std::ofstream& out, std::uint16_t value) {
    const char bytes[] = {
        static_cast<char>(value & 0xff),
        static_cast<char>((value >> 8) & 0xff),
    };
    out.write(bytes, sizeof(bytes));
}

static void write_u32(std::ofstream& out, std::uint32_t value) {
    const char bytes[] = {
        static_cast<char>(value & 0xff),
        static_cast<char>((value >> 8) & 0xff),
        static_cast<char>((value >> 16) & 0xff),
        static_cast<char>((value >> 24) & 0xff),
    };
    out.write(bytes, sizeof(bytes));
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "usage: mort_decoder INPUT.mort OUTPUT.wav\n";
        return 2;
    }

    std::ifstream input(argv[1], std::ios::binary);
    if (!input) {
        std::cerr << "could not open input MORT stream\n";
        return 3;
    }
    std::vector<unsigned char> mort(
        (std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    if (mort.size() < 12 || std::string(mort.begin(), mort.begin() + 4) != "MORT") {
        std::cerr << "input is not a MORT stream\n";
        return 4;
    }

    const std::uint16_t frame_count =
        static_cast<std::uint16_t>((mort[4] << 8) | mort[5]);
    const std::uint16_t sample_rate =
        static_cast<std::uint16_t>((mort[6] << 8) | mort[7]);
    const std::uint32_t word_count =
        (static_cast<std::uint32_t>(mort[8]) << 24) |
        (static_cast<std::uint32_t>(mort[9]) << 16) |
        (static_cast<std::uint32_t>(mort[10]) << 8) |
        static_cast<std::uint32_t>(mort[11]);
    if (sample_rate == 0 || word_count * 4 != mort.size()) {
        std::cerr << "invalid MORT header\n";
        return 5;
    }

    // The original decoder treats address zero as "no stream". Mirror N64
    // Sound Tool's proven call site by placing the MORT data after 0x1000
    // bytes of zero padding and decoding from that non-zero address.
    std::vector<unsigned char> decoder_input(0x1000 + mort.size(), 0);
    std::copy(mort.begin(), mort.end(), decoder_input.begin() + 0x1000);
    CMORTDecoder decoder;
    std::vector<unsigned short> samples;
    if (!decoder.Decode(decoder_input.data(), static_cast<int>(mort.size()), 0x1000,
                        static_cast<unsigned long>(mort.size()), samples)) {
        std::cerr << "MORT decoder rejected the stream\n";
        return 6;
    }
    const std::size_t expected = static_cast<std::size_t>(frame_count) * 160;
    if (samples.size() != expected) {
        std::cerr << "decoded sample count mismatch: got " << samples.size()
                  << ", expected " << expected << "\n";
        return 7;
    }

    std::ofstream output(argv[2], std::ios::binary);
    if (!output) {
        std::cerr << "could not create output WAV\n";
        return 8;
    }
    const std::uint32_t data_size = static_cast<std::uint32_t>(samples.size() * 2);
    output.write("RIFF", 4);
    write_u32(output, 36 + data_size);
    output.write("WAVEfmt ", 8);
    write_u32(output, 16);
    write_u16(output, 1);
    write_u16(output, 1);
    write_u32(output, sample_rate);
    write_u32(output, static_cast<std::uint32_t>(sample_rate) * 2);
    write_u16(output, 2);
    write_u16(output, 16);
    output.write("data", 4);
    write_u32(output, data_size);
    for (unsigned short sample : samples) {
        write_u16(output, sample);
    }
    if (!output) {
        std::cerr << "failed while writing output WAV\n";
        return 9;
    }
    return 0;
}
