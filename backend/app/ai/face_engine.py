import cv2
import numpy as np
import insightface

_app = None


def _get_app():
    global _app
    if _app is None:
        _app = insightface.app.FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"],
            allowed_modules=['detection', 'recognition'],
        )
        _app.prepare(ctx_id=0, det_size=(640, 640))
    return _app


def warm_up():
    """Load the model and run the detection and recognition graphs once, so the
    first pupil registration does not pay the ONNX cold-start (tens of seconds
    on a weak CPU). Called from a background thread at startup; failures here
    only mean the first real request is slow, so they are swallowed."""
    try:
        app = _get_app()
        blank = np.zeros((640, 640, 3), dtype=np.uint8)
        app.get(blank)                      # warms detection (SCRFD)
        rec = app.models.get("recognition") if hasattr(app, "models") else None
        if rec is not None:
            try:
                rec.get_feat(np.zeros((112, 112, 3), dtype=np.uint8))  # warms recognition (ArcFace)
            except Exception:
                pass
    except Exception:
        pass


def generate_face_encoding(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return None

    app = _get_app()
    faces = app.get(img)

    if not faces:
        return None

    face = max(
        faces,
        key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1])
    )

    return ",".join(map(str, face.embedding.tolist()))
