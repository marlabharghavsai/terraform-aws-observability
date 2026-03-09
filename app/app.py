from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello from Containerized Flask App on EC2!'

@app.route('/health')
def health_check():
    return 'OK', 200

if __name__ == '__main__':
    # Listen on all interfaces, port 80 (standard HTTP)
    app.run(debug=True, host='0.0.0.0', port=os.environ.get('PORT', 80))
