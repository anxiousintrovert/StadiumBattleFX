#!/usr/bin/env python3
"""Desktop GUI for building a locally cached StadiumBattleFX pack."""

from __future__ import annotations

import os
import platform
import queue
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from build_announcer_pack import build_announcer_pack


APP_TITLE = "StadiumBattleFX Personalized Pack Builder"


class BuilderApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(APP_TITLE)
        self.root.resizable(False, False)
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self.events: queue.Queue[tuple[str, object]] = queue.Queue()
        self.running = False
        self.output_touched = False
        self.completed_output: Path | None = None

        self.rom = tk.StringVar()
        self.stadium2_rom = tk.StringVar()
        self.pack = tk.StringVar()
        self.output = tk.StringVar()
        self.status = tk.StringVar(value="Choose your ROMs and the voice-free mod pack.")
        self.percent = tk.DoubleVar(value=0)

        outer = ttk.Frame(root, padding=18)
        outer.grid(sticky="nsew")
        ttk.Label(
            outer,
            text="Build a cached, personalized StadiumBattleFX pack",
            font=("Segoe UI Semibold", 13),
        ).grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 4))
        ttk.Label(
            outer,
            text=("Everything stays local. Only derived caches and announcer clips are "
                  "placed in the ZIP; never redistribute it."),
            foreground="#555555",
        ).grid(row=1, column=0, columnspan=3, sticky="w", pady=(0, 16))

        self._file_row(
            outer, 2, "Pokemon Stadium ROM", self.rom, self.choose_rom,
            "Select your Pokemon Stadium (USA) v1.0 .z64/.v64/.n64/.bin ROM."
        )
        self._file_row(
            outer, 5, "Pokemon Stadium 2 ROM (optional)", self.stadium2_rom,
            self.choose_stadium2_rom,
            "Adds the Stadium 2 normal/shiny appearance cache when selected."
        )
        self._file_row(
            outer, 8, "StadiumBattleFX pack", self.pack, self.choose_pack,
            "Select the downloaded voice-free StadiumBattleFX .zip."
        )
        self._file_row(
            outer, 11, "Personalized output", self.output, self.choose_output,
            "A new ZIP is created; the original pack is left unchanged."
        )

        ttk.Separator(outer).grid(row=14, column=0, columnspan=3, sticky="ew", pady=(16, 14))
        ttk.Progressbar(
            outer, variable=self.percent, maximum=100, length=580, mode="determinate"
        ).grid(row=15, column=0, columnspan=3, sticky="ew")
        ttk.Label(outer, textvariable=self.status).grid(
            row=16, column=0, columnspan=3, sticky="w", pady=(7, 16)
        )

        buttons = ttk.Frame(outer)
        buttons.grid(row=17, column=0, columnspan=3, sticky="e")
        self.open_button = ttk.Button(
            buttons, text="Open Output Folder", command=self.open_output, state="disabled"
        )
        self.open_button.grid(row=0, column=0, padx=(0, 8))
        self.build_button = ttk.Button(
            buttons, text="Build Personalized Pack", command=self.start_build
        )
        self.build_button.grid(row=0, column=1)
        outer.columnconfigure(1, weight=1)
        self.root.after(80, self.poll_events)

    def _file_row(
        self,
        parent: ttk.Frame,
        row: int,
        label: str,
        variable: tk.StringVar,
        browse,
        hint: str,
    ) -> None:
        ttk.Label(parent, text=label).grid(row=row, column=0, columnspan=3, sticky="w")
        ttk.Entry(parent, textvariable=variable, width=69).grid(
            row=row + 1, column=0, columnspan=2, sticky="ew", pady=(3, 0)
        )
        ttk.Button(parent, text="Browse...", command=browse, width=11).grid(
            row=row + 1, column=2, padx=(8, 0), pady=(3, 0)
        )
        ttk.Label(parent, text=hint, foreground="#666666").grid(
            row=row + 2, column=0, columnspan=3, sticky="w", pady=(2, 10)
        )

    def choose_rom(self) -> None:
        path = filedialog.askopenfilename(
            title="Select Pokemon Stadium ROM",
            filetypes=[("Nintendo 64 ROM", "*.z64 *.v64 *.n64 *.bin"), ("All files", "*.*")],
        )
        if path:
            self.rom.set(path)

    def choose_pack(self) -> None:
        path = filedialog.askopenfilename(
            title="Select voice-free StadiumBattleFX pack",
            filetypes=[("ZIP archive", "*.zip"), ("All files", "*.*")],
        )
        if path:
            self.pack.set(path)
            if not self.output_touched:
                source = Path(path)
                self.output.set(str(source.with_name(source.stem + "-personalized.zip")))

    def choose_stadium2_rom(self) -> None:
        path = filedialog.askopenfilename(
            title="Select Pokemon Stadium 2 ROM",
            filetypes=[("Nintendo 64 ROM", "*.z64 *.v64 *.n64 *.bin"), ("All files", "*.*")],
        )
        if path:
            self.stadium2_rom.set(path)

    def choose_output(self) -> None:
        initial = (Path(self.output.get()) if self.output.get()
                   else Path("StadiumBattleFX-personalized.zip"))
        path = filedialog.asksaveasfilename(
            title="Save personalized StadiumBattleFX pack",
            defaultextension=".zip",
            initialdir=str(initial.parent),
            initialfile=initial.name,
            filetypes=[("ZIP archive", "*.zip")],
        )
        if path:
            self.output_touched = True
            self.output.set(path)

    def start_build(self) -> None:
        rom = Path(self.rom.get().strip())
        stadium2_rom = (Path(self.stadium2_rom.get().strip())
                        if self.stadium2_rom.get().strip() else None)
        pack = Path(self.pack.get().strip())
        output = Path(self.output.get().strip())
        if not self.rom.get().strip() or not self.pack.get().strip() or not self.output.get().strip():
            messagebox.showerror(APP_TITLE, "Choose the ROM, base pack, and output ZIP first.")
            return
        if output.exists() and not messagebox.askyesno(
            APP_TITLE, f"Replace the existing output file?\n\n{output}"
        ):
            return
        if output.resolve() == pack.resolve():
            messagebox.showerror(APP_TITLE, "The output must be a new ZIP, not the base pack.")
            return

        self.running = True
        self.completed_output = None
        self.percent.set(0)
        self.status.set("Starting...")
        self.build_button.configure(state="disabled")
        self.open_button.configure(state="disabled")
        threading.Thread(
            target=self._build_worker,
            args=(rom, stadium2_rom, pack, output),
            daemon=True,
        ).start()

    def _build_worker(
        self, rom: Path, stadium2_rom: Path | None, pack: Path, output: Path
    ) -> None:
        try:
            result = build_announcer_pack(
                rom,
                pack,
                output,
                stadium2_rom=stadium2_rom,
                progress=lambda fraction, text: self.events.put(
                    ("progress", (fraction, text))
                ),
            )
        except Exception as exc:
            self.events.put(("error", str(exc)))
        else:
            self.events.put(("done", (output, result)))

    def poll_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "progress":
                    fraction, text = payload
                    self.percent.set(float(fraction) * 100)
                    self.status.set(str(text))
                elif kind == "error":
                    self.running = False
                    self.build_button.configure(state="normal")
                    self.status.set("Build failed. No personalized pack was created.")
                    messagebox.showerror(APP_TITLE, str(payload))
                elif kind == "done":
                    output, result = payload
                    self.running = False
                    self.completed_output = Path(output)
                    self.percent.set(100)
                    self.status.set("Done — personalized caches and announcer are ready.")
                    self.build_button.configure(state="normal")
                    self.open_button.configure(state="normal")
                    size_mb = result["zip_bytes"] / (1024 * 1024)
                    messagebox.showinfo(
                        APP_TITLE,
                        f"Your personalized pack is ready.\n\n{output}\n\n"
                        f"823 clips · {result['cache_files']} cache files · {size_mb:.1f} MB",
                    )
        except queue.Empty:
            pass
        self.root.after(80, self.poll_events)

    def open_output(self) -> None:
        if not self.completed_output:
            return
        folder = self.completed_output.resolve().parent
        if os.name == "nt":
            os.startfile(folder)
        else:
            try:
                subprocess.Popen(["xdg-open", str(folder)])
            except OSError as exc:
                messagebox.showerror(
                    APP_TITLE, f"Could not open the output folder:\n\n{exc}"
                )

    def close(self) -> None:
        if self.running:
            messagebox.showinfo(APP_TITLE, "Wait for the current build to finish before closing.")
            return
        self.root.destroy()


def main() -> None:
    if "--self-test" in sys.argv:
        from build_announcer_pack import default_decoder

        decoder = default_decoder()
        print(f"announcer builder self-test passed ({platform.system()}, {decoder})")
        return
    root = tk.Tk()
    try:
        root.iconname(APP_TITLE)
        ttk.Style(root).theme_use("vista")
    except tk.TclError:
        pass
    BuilderApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
