FROM python:3.11-slim

# No extras needed — sandbox runs isolated scripts only
WORKDIR /sandbox

# Non-root user for additional security
RUN useradd -m -u 1000 sandbox
USER sandbox

CMD ["python", "/sandbox/test_script.py"]
