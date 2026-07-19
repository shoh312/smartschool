import uvicorn

if __name__ == "__main__":
    # reload=False: the camera detection threads hold blocking native calls
    # (OpenCV/RTSP) that can prevent the reloader's old worker process from
    # ever exiting cleanly on Windows, silently hanging the server on any
    # file-watch trigger instead of actually restarting. Restart manually
    # after code changes instead.
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)
