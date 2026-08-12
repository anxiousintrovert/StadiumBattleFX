// Reverse Engineered by SubDrag from Pokemon Stadium
#pragma once

#include <cstdint>
#include <cstdio>

#include <vector>

class CMORTDecoder
{
public:
	CMORTDecoder(void);
	~CMORTDecoder(void);

public:
	bool Decode(unsigned char* ROM, int romSize, std::uint32_t address, std::uint32_t length, std::vector<unsigned short>& pcmSamples);

	static unsigned short CharArrayToShort(unsigned char* currentSpot);
	static std::uint32_t CharArrayToLong(unsigned char* currentSpot);
	static void WriteLongToBuffer(unsigned char* Buffer, std::uint32_t address, std::uint32_t data);
	static void WriteShortToBuffer(unsigned char* Buffer, std::uint32_t address, unsigned short data);
	static unsigned short Flip16Bit(unsigned short ShortValue);
	static std::uint32_t Flip32Bit(std::uint32_t inLong);
	static void WriteLongToFile(FILE* Buffer, std::uint32_t data);
	static void WriteShortToFile(FILE* Buffer, unsigned short data);

private:
	unsigned short buffer800D2940Predictor[0xA0];
	unsigned short lastPredictorUpdateBase; // 2-bytes buffer800D2940Predictor[0x189]
	bool currentSmootherPredictor; // 2-bytes buffer800D2940Predictor[0x166]
	signed short smootherPredictorA[8]; // 2-bytes buffer800D2940Predictor[0x168-0x178]
	signed short smootherPredictorB[8]; // 2-bytes buffer800D2940Predictor[0x178-0x188]
	int numberSkipResetPredictorCheck; // 2-bytes buffer800D2940Predictor[0x18A]
	int numberResetPredictor; // 2-bytes buffer800D2940Predictor[0x18C]
	std::uint32_t lastSampleValue; // 2-bytes buffer800D2940Predictor[0x164]
	std::int32_t sampleBuffer[8]; // 4-bytes buffer800D2940Predictor[0x140-0x15C]
	std::uint32_t buffer800D2940Subtraction;
	//800D2AD0 Pointer to function 800455DC (pull data?)
	// Need evaluate if these are part of buffer or not and the rest around there
	std::uint32_t variable800D2AD4ROMAddressMORTData;
	unsigned char buffer800D2AD8IntermediateValue[0x1400];
	std::uint32_t buffer800D2AD8Subtraction;
	unsigned char buffer800D3ED8MORTRawInputDataBuffer[0x1000]; // TWINE 800E1C60
	unsigned short variable800D4ED8Amountofsoundleft1_FirstWord; // TWINE 800E2C60
	unsigned short variable800D4EDA_3E80FirstWord;
	std::uint32_t variable800D4EDCAmountofCompressedWordsLeft_SecondWord;
	std::uint32_t variable800D4EE0;
	std::uint32_t variable800D4EE4;
	std::uint32_t variable800D4EE8;
	std::uint32_t variable800D4EEC;
	std::uint32_t variable800D4EF0;
	std::uint32_t variable800D4EF4;
	std::uint32_t variable800D4EFCInputChunkCurrentReadBitPosition;
	std::uint32_t variable800D4F00InputChunkUsed; // TWINE 800E2C8C
	std::uint32_t variable800D4F04InputChunkAmountLeft; // TWINE 800E2C90
	std::uint32_t variable800D4F08;
	std::uint32_t variable800D4F0C; //// TWINE 800E2C98
	unsigned char variable800D4F10Status1; // TWINE 800E2C9C
	unsigned char variable800D4F11Status2; //01 loading, 02 loaded, 03 playing, 04 ended
	unsigned char variable800D4F12Status3; // TWINE 800E2C9E
	unsigned char* buffer800D4F20OutputBuffer;
	std::uint32_t buffer800D4F20Subtraction;

	std::uint32_t variable800FCED0;
	std::uint32_t variable800FCEDCPredictorPointer800D2940;
	std::uint32_t variable800FCEE8;
	std::uint32_t variable800FCEECCounter;
	unsigned char variable800FCEF0MORTStatus1; //Status of sound, 00 = Loading, 02 = none, 04 = Playing
	unsigned char variable800FCEF1MORTStatus2; //Status of sound, 00 = Loading, 02 = none, 04 = Playing
	std::uint32_t variable800FCEFCROMMORTSoundAddress;
	std::uint32_t variable800FCF04;
	std::uint32_t variable800FCF0CVolume;
	unsigned char variable800FCF20;
	unsigned char variable800FCF21;
	std::uint32_t variable800FCF2COutputBufferPointer800D4F20;
	std::uint32_t variable800FCF30CounterPlay1;
	std::uint32_t variable800FCF34CounterPlay2;
	std::uint32_t variable800FCF38CounterIncrementVariable1;
	std::uint32_t variable800FCF3CCounterIncrementVariable2;

	void Function800456D0();
	void Function80045780(unsigned char* ROM, bool& started, std::vector<unsigned short>& pcmSamples);
	void Function800459E0(std::uint32_t A1Param, std::uint32_t& V0);
	void Function8005E3A0(std::uint32_t A1Param, std::uint32_t A2Param);
	void ClearBuffer_Function80057FD0(std::uint32_t A0Param, std::uint32_t A1Param);
	void Function80059120(std::uint32_t A0Param, std::uint32_t A1Param);
	void Function800455DC(unsigned char* ROM, std::uint32_t A0Param, std::uint32_t A1Param, std::uint32_t A2Param);
	void Function8005E2F0(std::uint32_t A0Param, std::uint32_t A1Param);
	void Function8005E0F0();
	void Function80056AD0(std::uint32_t& V0);
	void Function80062A90(std::uint32_t& V0);
	void Function80045FF0(std::uint32_t currentIntermediateValueOffset, std::vector<unsigned short>& pcmSamples);
	void Function80045C78(int currentIntermediateValueOffset, unsigned short shortsSP60[4][0xD], unsigned short shortsSPC8[0x4], unsigned short shortsSPD0[0x4], unsigned short stackBuffer2Offsets[0x4], unsigned short shortsSPE0[0x4], unsigned short shortsSPE8[8], std::vector<unsigned short>& pcmSamples);
	void Function80048590(unsigned short shortsSPC8Value, unsigned short stackBuffer2Offset, unsigned short stackBuffer2[0x28], unsigned short shortsSP60[0xD]);
	void Function80048684(unsigned short shortsSPE0Value, unsigned short shortsSPD0Value, unsigned short stackBuffer2[0x28]);
	void Function80045A80(std::uint32_t currentIntermediateValueOffset, unsigned short shortsSPE8[8], std::vector<unsigned short>& pcmSamples);
	void Function80048904(std::uint32_t currentIntermediateValueOffset, std::vector<unsigned short>& pcmSamples);
	void CallT380048XXXFunction(std::uint32_t& T2, std::uint32_t T3, std::uint32_t T4);
	void Function80048AFC(std::uint32_t& T2, std::uint32_t T4);
	void Function80048B14(std::uint32_t& T2, std::uint32_t T4);
	void Function80048B24(std::uint32_t& T2, std::uint32_t T4);
	void Function80048B3C(std::uint32_t& T2);
	void Function80048740(std::uint32_t intermediateValueOffset, std::uint32_t predictorBufferOffset, int countValues, signed short adjusters[8], std::uint32_t& A3, std::uint32_t& S0, std::uint32_t& S1, std::uint32_t& S2, std::uint32_t& S3, std::uint32_t& S4, std::uint32_t& S5, std::uint32_t& S6, std::uint32_t& S7, std::vector<unsigned short>& pcmSamples);
	void Function80048A58(std::uint32_t T3Param, signed short adjuster[8]);
	void Function80045A48();
	void Function80045A68();

	std::uint32_t ReadBitsFrom80045FF0Buffer(int numberBits, unsigned char* buffer800D3ED8MORTRawInputDataBuffer, std::uint32_t& currentInputData, std::uint32_t& bitsleft, std::uint32_t& currentOverallBitPosition);

	FILE* outDebug;
	bool setInputChunk;

	void WriteBitsTo80045FF0Buffer(unsigned char* buffer, int& bufferOffset, int& bufferBitOffset, int numBits, unsigned char value);
};
