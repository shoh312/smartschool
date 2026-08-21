"""Is this computer fast enough to run SmartSchool's face recognition?

Run it on the machine you are thinking of putting in a school, before you
buy or commit to it. It times the real model at the real settings rather
than reading the spec sheet, because the only number that matters is how
long one pass over a classroom actually takes on that hardware.

    cd backend
    venv\\Scripts\\python.exe ..\\scripts\\check_machine.py
    venv\\Scripts\\python.exe ..\\scripts\\check_machine.py --pupils 30

The model runs on the CPU only (see live_detection.py -- the provider is
CPUExecutionProvider and the installed onnxruntime is the CPU build), so a
graphics card makes no difference to any of this.
"""

import argparse
import platform
import sys
import time

import cv2
import numpy as np

# What live_detection.py uses. Kept in sync by hand: if those change, change
# these, or this script stops answering the question it claims to answer.
DET_SIZE = (960, 960)
RESIZE = 0.5
DETECT_SECONDS = 10

# The app runs only these two: the landmark and age/gender models in the
# pack are never read, and skipping them cuts about a third off the cost of
# every face. Timing the full pack here would overstate what a machine
# needs -- see live_detection.py.
ALLOWED_MODULES = ['detection', 'recognition']

# A pass has to finish inside the detect window with room to spare -- a
# machine that needs the whole window gets one attempt and no second chance
# if a pupil happened to look away.
COMFORTABLE_FRACTION = 0.35
ACCEPTABLE_FRACTION = 0.7


def describe_machine():
    print("KOMPYUTER")
    print("  tizim   : %s %s" % (platform.system(), platform.release()))
    print("  protsessor: %s" % (platform.processor() or "noma'lum"))
    try:
        import os
        print("  yadro   : %s" % (os.cpu_count() or "noma'lum"))
    except Exception:
        pass
    print()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pupils", type=int, default=15,
                        help="Sinfdagi bolalar soni (default 15)")
    args = parser.parse_args()

    describe_machine()

    try:
        import insightface
    except ImportError:
        print("XATO: insightface o'rnatilmagan.")
        print("Buni backend muhitidan ishga tushiring:")
        print("  cd backend")
        print("  venv\\Scripts\\python.exe ..\\scripts\\check_machine.py")
        return 1

    print("Model yuklanyapti (buffalo_l, CPU)...")
    started = time.time()
    app = insightface.app.FaceAnalysis(name="buffalo_l",
                                       providers=["CPUExecutionProvider"],
                                       allowed_modules=ALLOWED_MODULES)
    app.prepare(ctx_id=0, det_size=DET_SIZE)
    print("  %.1f soniyada yuklandi" % (time.time() - started))
    print()

    # Timing depends on the input size and the model, not on the picture's
    # contents, so a synthetic frame measures the same thing as a real one
    # and needs nobody's photo to do it.
    frame = np.random.randint(0, 255, (1080, 1920, 3), dtype=np.uint8)
    small = cv2.resize(frame, (0, 0), fx=RESIZE, fy=RESIZE)

    app.get(small)  # warm-up

    samples = []
    for _ in range(5):
        t0 = time.time()
        app.get(small)
        samples.append(time.time() - t0)
    samples.sort()
    detect_ms = samples[len(samples) // 2] * 1000

    # Each detected face costs a second pass through the landmark and
    # recognition nets, and in a classroom that is most of the work.
    per_face_ms = 0.0
    for taskname, model in app.models.items():
        if taskname == 'detection':
            continue
        session = model.session
        shape = session.get_inputs()[0].shape
        h = shape[2] if isinstance(shape[2], int) else 112
        w = shape[3] if isinstance(shape[3], int) else 112
        input_name = session.get_inputs()[0].name
        data = np.random.rand(1, 3, h, w).astype(np.float32)
        session.run(None, {input_name: data})
        runs = []
        for _ in range(8):
            t0 = time.time()
            session.run(None, {input_name: data})
            runs.append(time.time() - t0)
        runs.sort()
        per_face_ms += runs[len(runs) // 2] * 1000

    total_ms = detect_ms + per_face_ms * args.pupils
    total_s = total_ms / 1000

    print("O'LCHOV")
    print("  yuzlarni topish     : %.0f ms" % detect_ms)
    print("  har bir yuzni tanish: %.0f ms" % per_face_ms)
    print("  %d bola bilan jami  : %.1f soniya" % (args.pupils, total_s))
    print()

    budget = DETECT_SECONDS
    print("XULOSA  (aniqlash oynasi %d soniya)" % budget)
    if total_s <= budget * COMFORTABLE_FRACTION:
        print("  YAXSHI -- bu kompyuter bemalol yetadi.")
        print("  Oyna ichida %d martagacha urinib ko'radi." % int(budget / total_s))
    elif total_s <= budget * ACCEPTABLE_FRACTION:
        print("  YETADI -- ishlaydi, lekin zaxira kam.")
        print("  Bitta sinf uchun mayli; ikkinchi sinf qo'shilsa kuchliroq kerak.")
    elif total_s <= budget:
        print("  CHEGARADA -- oynaga zo'rg'a sig'yapti.")
        print("  Bir urinishdan ortig'iga vaqt yo'q: bola qarab turmasa qoladi.")
        print("  Kuchliroq protsessor tavsiya qilinadi.")
    else:
        print("  YETMAYDI -- bir tahlil oynadan uzoq davom etadi.")
        print("  Bu kompyuterda bolalar to'liq aniqlanmaydi.")
    print()
    print("  Eslatma: videokarta bu raqamlarga ta'sir qilmaydi -- model")
    print("  faqat protsessorda ishlaydi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
