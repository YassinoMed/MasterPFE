import re
from pathlib import Path

TEMPLATES_DIR = Path("/root/MasterPFE/services/extraire/src/templates")

links_map = {
    'href="#"': '', # We will handle them contextually below or use regex
    '>Dashboard<': 'href="/dashboard">Dashboard<',
    '>Upload<': 'href="/upload">Upload<',
    '>History<': 'href="/history">History<',
    '>Settings<': 'href="/settings">Settings<'
}

def fix_file(filepath):
    content = filepath.read_text()
    
    # Fix navigation links globally
    content = re.sub(r'href="#"([^>]*)>(\s*<span[^>]*>[^<]*</span>\s*<span[^>]*>)Dashboard<', r'href="/dashboard"\1>\2Dashboard<', content)
    content = re.sub(r'href="#"([^>]*)>(\s*<span[^>]*>[^<]*</span>\s*<span[^>]*>)Upload<', r'href="/upload"\1>\2Upload<', content)
    content = re.sub(r'href="#"([^>]*)>(\s*<span[^>]*>[^<]*</span>\s*<span[^>]*>)History<', r'href="/history"\1>\2History<', content)
    content = re.sub(r'href="#"([^>]*)>(\s*<span[^>]*>[^<]*</span>\s*<span[^>]*>)Settings<', r'href="/settings"\1>\2Settings<', content)
    
    # Upload specific changes
    if filepath.name == 'upload.html':
        # Add form tag around the grid content
        content = content.replace(
            '<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">',
            '<form action="/upload" method="post" enctype="multipart/form-data" class="grid grid-cols-1 lg:grid-cols-12 gap-6">'
        )
        content = content.replace(
            '<!-- Right Column: Settings Panel (4 cols) -->',
            '<!-- Right Column: Settings Panel (4 cols) -->'
        )
        # Add name="file" and remove multiple
        content = content.replace(
            'id="file-input" multiple="" type="file"/>',
            'id="file-input" name="file" type="file" required/>'
        )
        # Add name="format" to the model/language selects or at least a hidden input? The backend expects format in "format" (xlsx, json, txt, xml)
        # We can just append a hidden input for now since the prototype radio buttons are named "model" and options are languages
        content = content.replace(
            '<input class="mt-1 text-primary focus:ring-primary border-outline" name="model" type="radio"/>',
            '<input class="mt-1 text-primary focus:ring-primary border-outline" name="model" type="radio" value="deep"/>'
        )
        # Change the start extraction button to type=submit
        content = content.replace(
            '<button class="w-full bg-primary hover:bg-on-primary-fixed-variant text-on-primary',
            '<button type="submit" class="w-full bg-primary hover:bg-on-primary-fixed-variant text-on-primary'
        )
        # Close the form instead of the div where grid ends
        # In upload.html, the grid ends after the 2 columns
        content = content.replace(
            '</div>\n</div>\n</div>\n</main>',
            '</form>\n</div>\n</main>'
        )

        # Add flash messages placeholder below the page header
        flash_snippet = """
        {% with messages = get_flashed_messages(with_categories=true) %}
          {% if messages %}
            {% for category, message in messages %}
              <div class="mb-4 p-4 rounded-lg {% if category == 'success' %}bg-green-100 border border-green-400 text-green-700{% else %}bg-red-100 border border-red-400 text-red-700{% endif %}">
                {{ message }}
              </div>
            {% endfor %}
          {% endif %}
        {% endwith %}
        """
        content = content.replace(
            '<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">',
            flash_snippet + '\n<form action="/upload" method="post" enctype="multipart/form-data" class="grid grid-cols-1 lg:grid-cols-12 gap-6">'
        )

    filepath.write_text(content)

for f in TEMPLATES_DIR.glob('*.html'):
    fix_file(f)

print("Templates fixed successfully!")
