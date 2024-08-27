import os
from flask import Flask, render_template

base_dir = os.path.dirname(os.path.abspath(__file__))
static_folder_path = os.path.abspath(os.path.join(base_dir, '../../../frontend/web'))
template_folder_path = os.path.abspath(os.path.join(base_dir, '../../../frontend/web/templates'))

app = Flask(__name__, static_folder=static_folder_path, template_folder=template_folder_path, static_url_path='/')

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True)
