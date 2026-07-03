import cv2
import numpy as np
import insightface

_app = None


def _get_app():
    global _app
    if _app is None:
        _app = insightface.app.FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"]
        )
        _app.prepare(ctx_id=0, det_size=(640, 640))
    return _app


def generate_face_encoding(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return None

    app = _get_app()
    faces = app.get(img)

    if not faces:
        return None

    # Eng katta yuzni olish
    face = max(
        faces,
        key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1])
    )

    return ",".join(map(str, face.embedding.tolist()))
