from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# Global variable to hold routine data
routine_data = pd.DataFrame()

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'online',
        'message': 'DIU Routine Scraper Backend is running',
        'endpoints': {
            '/routine/<batch_code>': 'GET - Filter routine by batch',
            '/upload': 'POST - Upload Excel/CSV routine'
        }
    })

@app.route('/routine/<batch_code>', methods=['GET'])
def get_routine(batch_code):
    global routine_data
    if routine_data.empty:
        return jsonify({'message': 'No routine loaded. Please upload a routine file.'}), 404
    
    try:
        # Case-insensitive filtering on 'section' column
        filtered = routine_data[routine_data['section'].astype(str).str.lower() == batch_code.lower()]
        
        if filtered.empty:
            return jsonify({'message': f'No routine found for batch {batch_code}.'}), 404
            
        return jsonify(filtered.to_dict(orient='records'))
    except Exception as e:
        return jsonify({'error': f'Filtering error: {str(e)}'}), 500

@app.route('/upload', methods=['POST'])
def upload_routine():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in the request'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected for uploading'}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    try:
        if filepath.endswith('.xlsx'):
            df = pd.read_excel(filepath)
        elif filepath.endswith('.csv'):
            df = pd.read_csv(filepath)
        else:
            return jsonify({'error': 'Unsupported file format. Use Excel (.xlsx) or CSV.'}), 400

        # Basic validation: ensure 'section' column exists
        if 'section' not in df.columns.str.lower():
            # Try to find a column that looks like section/batch
            cols = {c.lower(): c for c in df.columns}
            if 'section' in cols:
                df.rename(columns={cols['section']: 'section'}, inplace=True)
            elif 'batch' in cols:
                df.rename(columns={cols['batch']: 'section'}, inplace=True)
            else:
                 return jsonify({'error': 'Required column "section" not found in file.'}), 400

        global routine_data
        # Normalize column names to lowercase for consistency
        df.columns = [c.lower() for c in df.columns]
        routine_data = df  
        
        return jsonify({
            'message': 'Routine updated successfully!',
            'columns': list(df.columns),
            'rows': len(df)
        }), 200
    except Exception as e:
        return jsonify({'error': f'Processing error: {str(e)}'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
