FROM ghcr.io/mlflow/mlflow:v2.22.0

# The published image does not install the auth extra. `mlflow server --app-name
# basic-auth` imports Flask-WTF and exits when that package is missing.
USER root
RUN pip install --no-cache-dir "mlflow[auth]==2.22.0"
