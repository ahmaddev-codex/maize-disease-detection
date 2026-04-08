"""
Phase 4 — Raspberry Pi Tkinter GUI
Farmer-facing desktop app for on-device maize disease detection.

Features:
  - Load image from file or capture from PiCamera2
  - Run TFLite INT8 inference on-device
  - Display disease name, confidence bar, and treatment recommendation
  - Latency indicator (green < 1s, yellow < 2s, red > 2s)

Run on Raspberry Pi:
    python deployment/raspberry_pi/app.py
    python deployment/raspberry_pi/app.py --model /path/to/model.tflite

Dependencies (Pi):
    sudo apt install python3-tk
    pip install pillow tflite-runtime

On a dev machine (macOS/Linux) TFLite is included in tensorflow.
PiCamera2 is Pi-only; the app falls back to file-open if unavailable.
"""

import os
import sys
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
import threading

# Add project root to path so imports work when run directly on Pi
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from src.phase4_edge.inference import load_interpreter, run_inference, CLASS_NAMES

# ── Constants ─────────────────────────────────────────────────────────────────

DEFAULT_MODEL = os.path.join(
    os.path.dirname(__file__), "..", "..", "models", "exports",
    "efficientnetb3_maize_int8.tflite"
)

PREVIEW_SIZE = (400, 400)

TREATMENTS = {
    0: (
        "Northern Corn Leaf Blight (NCLB)",
        "• Apply foliar fungicide (mancozeb or azoxystrobin)\n"
        "• Remove and destroy heavily infected leaves\n"
        "• Plant resistant varieties (SAMMAZ 15, SAMMAZ 29)\n"
        "• Avoid overhead irrigation; improve field drainage"
    ),
    1: (
        "Common Rust",
        "• Apply triazole fungicide early (propiconazole)\n"
        "• Scout weekly — rust spreads rapidly in cool humid weather\n"
        "• Plant rust-resistant hybrids for next season\n"
        "• Ensure adequate potassium nutrition"
    ),
    2: (
        "Gray Leaf Spot (GLS)",
        "• Apply strobilurin fungicide (azoxystrobin) at first sign\n"
        "• Increase plant spacing to improve air circulation\n"
        "• Practice crop rotation (avoid maize monoculture)\n"
        "• Remove crop debris after harvest"
    ),
    3: (
        "Healthy",
        "• No disease detected — continue regular scouting\n"
        "• Maintain balanced NPK fertilisation schedule\n"
        "• Monitor for early-stage symptoms every 7–10 days"
    ),
}

CONFIDENCE_COLORS = {
    "high":   "#27ae60",   # green  ≥ 80%
    "medium": "#f39c12",   # amber  50–80%
    "low":    "#e74c3c",   # red    < 50%
}

LATENCY_COLORS = {
    "fast":   "#27ae60",   # < 1 s
    "ok":     "#f39c12",   # 1–2 s
    "slow":   "#e74c3c",   # > 2 s
}


# ── Main App ──────────────────────────────────────────────────────────────────

class MaizeApp(tk.Tk):
    def __init__(self, model_path: str):
        super().__init__()

        self.title("Maize Disease Detector")
        self.resizable(False, False)
        self.configure(bg="#1a1a2e")

        self.interpreter  = None
        self.model_path   = os.path.abspath(model_path)
        self._image_path  = None
        self._photo_ref   = None   # prevent GC of ImageTk

        self._build_ui()
        self._load_model_async()

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        PAD = 12

        # ── Header ──────────────────────────────────────────────────────────
        header = tk.Frame(self, bg="#16213e")
        header.pack(fill="x")
        tk.Label(
            header, text="Maize Disease Detector",
            font=("Helvetica", 18, "bold"),
            bg="#16213e", fg="#e2b96f", pady=10,
        ).pack()
        tk.Label(
            header, text="Powered by EfficientNetB3 · TFLite INT8",
            font=("Helvetica", 9), bg="#16213e", fg="#7f8c9a",
        ).pack(pady=(0, 8))

        # ── Main area ────────────────────────────────────────────────────────
        main = tk.Frame(self, bg="#1a1a2e")
        main.pack(padx=PAD, pady=PAD)

        # Left: image preview + buttons
        left = tk.Frame(main, bg="#1a1a2e")
        left.grid(row=0, column=0, padx=(0, PAD))

        self._preview_label = tk.Label(
            left, bg="#0f3460",
            width=PREVIEW_SIZE[0], height=PREVIEW_SIZE[1],
            text="No image loaded", fg="#7f8c9a",
            font=("Helvetica", 12),
        )
        self._preview_label.pack()

        btn_frame = tk.Frame(left, bg="#1a1a2e")
        btn_frame.pack(pady=(8, 0), fill="x")

        self._btn_open = self._make_button(btn_frame, "Open Image", self._open_image)
        self._btn_open.pack(side="left", expand=True, fill="x", padx=(0, 4))

        self._btn_camera = self._make_button(btn_frame, "Camera", self._capture_camera,
                                              bg="#0f3460")
        self._btn_camera.pack(side="left", expand=True, fill="x")

        self._btn_predict = self._make_button(
            left, "Run Detection", self._run_prediction, bg="#e2b96f", fg="#1a1a2e"
        )
        self._btn_predict.pack(pady=(8, 0), fill="x")
        self._btn_predict.config(state="disabled")

        # Right: results panel
        right = tk.Frame(main, bg="#16213e", padx=16, pady=16, relief="flat", bd=0)
        right.grid(row=0, column=1, sticky="nsew")

        tk.Label(right, text="Detection Result", font=("Helvetica", 13, "bold"),
                 bg="#16213e", fg="#e2e2e2").pack(anchor="w")

        # Disease label
        self._disease_var = tk.StringVar(value="—")
        tk.Label(right, textvariable=self._disease_var,
                 font=("Helvetica", 15, "bold"),
                 bg="#16213e", fg="#e2b96f",
                 wraplength=300, justify="left").pack(anchor="w", pady=(8, 4))

        # Confidence bar
        tk.Label(right, text="Confidence", font=("Helvetica", 9),
                 bg="#16213e", fg="#7f8c9a").pack(anchor="w")
        self._conf_bar = ttk.Progressbar(right, length=300, maximum=100)
        self._conf_bar.pack(anchor="w", pady=(2, 0))
        self._conf_label = tk.Label(right, text="", font=("Helvetica", 10),
                                    bg="#16213e", fg="#e2e2e2")
        self._conf_label.pack(anchor="w")

        # All scores
        tk.Frame(right, bg="#2c3e50", height=1).pack(fill="x", pady=10)
        tk.Label(right, text="Class Scores", font=("Helvetica", 9),
                 bg="#16213e", fg="#7f8c9a").pack(anchor="w")
        self._score_frame = tk.Frame(right, bg="#16213e")
        self._score_frame.pack(anchor="w", fill="x")
        self._score_labels = []
        for name in ["NCLB", "Rust", "GLS", "Healthy"]:
            row = tk.Frame(self._score_frame, bg="#16213e")
            row.pack(fill="x", pady=1)
            tk.Label(row, text=f"{name:<10}", width=10, anchor="w",
                     font=("Courier", 9), bg="#16213e", fg="#bdc3c7").pack(side="left")
            lbl = tk.Label(row, text="", anchor="w",
                           font=("Courier", 9), bg="#16213e", fg="#27ae60")
            lbl.pack(side="left")
            self._score_labels.append(lbl)

        # Treatment
        tk.Frame(right, bg="#2c3e50", height=1).pack(fill="x", pady=10)
        tk.Label(right, text="Recommended Action", font=("Helvetica", 9),
                 bg="#16213e", fg="#7f8c9a").pack(anchor="w")
        self._treatment_var = tk.StringVar(value="Run detection to see recommendations.")
        tk.Label(right, textvariable=self._treatment_var,
                 font=("Helvetica", 9),
                 bg="#16213e", fg="#e2e2e2",
                 wraplength=300, justify="left").pack(anchor="w", pady=(4, 0))

        # Latency
        tk.Frame(right, bg="#2c3e50", height=1).pack(fill="x", pady=10)
        self._latency_label = tk.Label(right, text="Latency: —",
                                       font=("Helvetica", 9),
                                       bg="#16213e", fg="#7f8c9a")
        self._latency_label.pack(anchor="w")

        # ── Status bar ───────────────────────────────────────────────────────
        self._status_var = tk.StringVar(value="Loading model…")
        tk.Label(self, textvariable=self._status_var,
                 font=("Helvetica", 9), bg="#0f3460", fg="#7f8c9a",
                 anchor="w", padx=8, pady=4).pack(fill="x", side="bottom")

    def _make_button(self, parent, text, command, bg="#0e4d6e", fg="white"):
        return tk.Button(
            parent, text=text, command=command,
            bg=bg, fg=fg, relief="flat",
            font=("Helvetica", 10, "bold"),
            padx=10, pady=6, cursor="hand2",
            activebackground="#1a6e96", activeforeground="white",
        )

    # ── Model loading ─────────────────────────────────────────────────────────

    def _load_model_async(self):
        def _load():
            try:
                self.interpreter = load_interpreter(self.model_path)
                self.after(0, lambda: self._status_var.set(
                    f"Model ready: {os.path.basename(self.model_path)}"
                ))
            except FileNotFoundError as e:
                self.after(0, lambda: messagebox.showerror("Model Error", str(e)))
                self.after(0, lambda: self._status_var.set("ERROR: model not found"))

        threading.Thread(target=_load, daemon=True).start()

    # ── Image handling ────────────────────────────────────────────────────────

    def _open_image(self):
        path = filedialog.askopenfilename(
            title="Select maize leaf image",
            filetypes=[("Images", "*.jpg *.jpeg *.png *.bmp"), ("All files", "*.*")],
        )
        if path:
            self._load_preview(path)

    def _capture_camera(self):
        """Capture from PiCamera2 if available, otherwise show error."""
        try:
            from picamera2 import Picamera2
        except ImportError:
            messagebox.showinfo(
                "Camera unavailable",
                "PiCamera2 is only available on Raspberry Pi.\nUse 'Open Image' instead."
            )
            return

        try:
            cam = Picamera2()
            cam.configure(cam.create_still_configuration(
                main={"size": (1920, 1080), "format": "RGB888"}
            ))
            cam.start()
            import time; time.sleep(0.5)   # warm-up
            array = cam.capture_array()
            cam.close()

            import tempfile
            tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
            Image.fromarray(array).save(tmp.name)
            self._load_preview(tmp.name)
            self._status_var.set("Camera capture complete")
        except Exception as e:
            messagebox.showerror("Camera Error", str(e))

    def _load_preview(self, path: str):
        self._image_path = path
        img = Image.open(path).convert("RGB")
        img.thumbnail(PREVIEW_SIZE, Image.LANCZOS)
        self._photo_ref = ImageTk.PhotoImage(img)
        self._preview_label.configure(image=self._photo_ref, text="")
        self._btn_predict.config(state="normal")
        self._status_var.set(f"Image loaded: {os.path.basename(path)}")

    # ── Inference ─────────────────────────────────────────────────────────────

    def _run_prediction(self):
        if not self._image_path:
            return
        if self.interpreter is None:
            messagebox.showwarning("Not ready", "Model is still loading. Please wait.")
            return

        self._btn_predict.config(state="disabled", text="Running…")
        self._status_var.set("Running inference…")

        def _infer():
            try:
                result = run_inference(self.interpreter, self._image_path)
                self.after(0, lambda: self._display_result(result))
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("Inference Error", str(e)))
                self.after(0, lambda: self._status_var.set("Inference failed"))
            finally:
                self.after(0, lambda: self._btn_predict.config(
                    state="normal", text="Run Detection"
                ))

        threading.Thread(target=_infer, daemon=True).start()

    def _display_result(self, result: dict):
        cid  = result["class_id"]
        conf = result["confidence"]
        lat  = result["latency_ms"]

        # Disease name
        _, short_name = TREATMENTS[cid][0], CLASS_NAMES[cid]
        self._disease_var.set(TREATMENTS[cid][0])

        # Confidence bar
        pct = conf * 100
        self._conf_bar["value"] = pct
        color = (CONFIDENCE_COLORS["high"] if pct >= 80
                 else CONFIDENCE_COLORS["medium"] if pct >= 50
                 else CONFIDENCE_COLORS["low"])
        self._conf_label.config(text=f"{pct:.1f}%", fg=color)

        # All scores
        short_names = ["NCLB", "Rust", "GLS", "Healthy"]
        for i, (lbl, score) in enumerate(zip(self._score_labels, result["all_scores"])):
            bar = "█" * int(score * 20)
            lbl.config(text=f"{score * 100:5.1f}%  {bar}",
                       fg="#e2b96f" if i == cid else "#7f8c9a")

        # Treatment
        self._treatment_var.set(TREATMENTS[cid][1])

        # Latency
        lat_color = (LATENCY_COLORS["fast"] if lat < 1000
                     else LATENCY_COLORS["ok"] if lat < 2000
                     else LATENCY_COLORS["slow"])
        self._latency_label.config(
            text=f"Latency: {lat:.0f} ms  {'✓ <2s target' if lat < 2000 else '✗ >2s target'}",
            fg=lat_color,
        )

        self._status_var.set(
            f"Result: {TREATMENTS[cid][0].split('(')[0].strip()} — {pct:.1f}% confidence"
        )


# ── Entry point ───────────────────────────────────────────────────────────────

def parse_args():
    import argparse
    p = argparse.ArgumentParser(description="Maize Disease Detector — Raspberry Pi GUI")
    p.add_argument("--model", default=DEFAULT_MODEL,
                   help="Path to .tflite model file")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    app = MaizeApp(model_path=args.model)
    app.mainloop()
