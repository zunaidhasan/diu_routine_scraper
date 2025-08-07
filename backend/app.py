from flask import Flask, request, jsonify
import pandas as pd
import os

app = Flask(__name__)
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# Global variable to hold routine data
routine_data = pd.DataFrame()

@app.route('/routine/<batch_code>', methods=['GET'])
def get_routine(batch_code):
    if routine_data.empty:
        return jsonify({'message': 'No routine loaded. Upload or wait for auto-fetch.'}), 404
    filtered = routine_data[routine_data['section'].str.lower() == batch_code.lower()]
    if filtered.empty:
        return jsonify({'message': f'No routine found for batch {batch_code}.'}), 404
    return jsonify(filtered.to_dict(orient='records'))

@app.route('/upload', methods=['POST'])
def upload_routine():
    file = request.files['file']
    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    try:
        if filepath.endswith('.xlsx'):
            df = pd.read_excel(filepath)
        elif filepath.endswith('.csv'):
            df = pd.read_csv(filepath)
        else:
            return jsonify({'error': 'Unsupported file format. Use Excel or CSV.'}), 400

        global routine_data
        routine_data = df  # Update global data
        return jsonify({'message': 'Routine updated successfully!'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
