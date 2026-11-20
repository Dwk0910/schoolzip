FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml ./
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package

FROM eclipse-temurin:21-jre-jammy
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 schoolzip \
    && useradd --uid 10001 --gid schoolzip --create-home schoolzip \
    && mkdir -p /app /data && chown schoolzip:schoolzip /app /data
WORKDIR /app
COPY requirements.txt ./
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
COPY --from=build /build/target/schoolzip-0.1.0.jar ./schoolzip.jar
COPY parser.py ./parser.py
ENV SCHOOLZIP_PYTHON=/opt/venv/bin/python \
    SCHOOLZIP_NAMES_DB=/data/teacher-names \
    PORT=8080
USER schoolzip
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:${PORT}/api/health || exit 1
CMD ["java", "-Xmx512m", "-XX:+ExitOnOutOfMemoryError", "-jar", "/app/schoolzip.jar"]
