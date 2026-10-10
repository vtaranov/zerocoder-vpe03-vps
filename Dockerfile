FROM python:3.12-alpine
ARG REVISION=local
WORKDIR /app
COPY app.py index.html VERSION ./
RUN printf '%s\n' "$REVISION" > REVISION
USER 65534:65534
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)" || exit 1
CMD ["python", "app.py"]
