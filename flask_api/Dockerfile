# 使用 Python 3.11 官方鏡像
FROM python:3.11-slim

# 設置工作目錄
WORKDIR /app

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 複製 requirements.txt 並安裝 Python 依賴
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用程序代碼
COPY . .

# 暴露端口
EXPOSE 8080

# 設置環境變數
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PORT=8080

# 啟動命令
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]