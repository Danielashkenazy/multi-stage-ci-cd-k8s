FROM python:3.11-slim
WORKDIR /app
COPY . . 
RUN pip3 install -r requirments.txt
ENTRYPOINT ["python3", "./main.py"]
EXPOSE 8000
