
import requests
import datetime
import csv
from flask import Flask,jsonify
app = Flask(__name__)

@app.route('/health')
def healthcheck():
    return jsonify(status="ok"),200

@app.route('/api')
def data():
    url = "https://rickandmortyapi.com/api/character"
    final_data = []
    with open('results.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['name', 'Origin', 'link'])
        while url:
            params = {"species": "Human", "status": "Alive"}
            response = requests.get(url, params=params)
            if response.status_code == 200:
                data = response.json()
                for character in data['results']:
                    if "Earth" in character['origin']['name']:
                        writer.writerow([character['name'], character['origin']['name'], character['image']])
                        final_data.append({
                            'name':character['name'],
                            'origin': character['location']['name'],
                            'image': character['image']
                        })
                url = data['info']['next']
                params = None
    return jsonify(final_data)



if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)