import re
from pathlib import Path

history_file = Path("/root/MasterPFE/services/extraire/src/templates/history.html")
content = history_file.read_text()

# Extract from <tbody class="font-body-sm text-body-sm text-on-surface divide-y divide-border-slate"> to </tbody>
tbody_start = '<tbody class="font-body-sm text-body-sm text-on-surface divide-y divide-border-slate">'
tbody_end = '</tbody>'

start_idx = content.find(tbody_start) + len(tbody_start)
end_idx = content.find(tbody_end, start_idx)

jinja_row = """
{% for f in files %}
<tr class="hover:bg-surface-container-low transition-colors group">
<td class="p-4 text-center">
<input class="w-4 h-4 text-primary border-outline rounded focus:ring-primary cursor-pointer" type="checkbox"/>
</td>
<td class="p-4 font-medium flex items-center gap-2">
<span class="material-symbols-outlined text-outline text-[18px]">description</span>
    {{ f }}
</td>
<td class="p-4 text-on-surface-variant whitespace-nowrap">Just now</td>
<td class="p-4">Document</td>
<td class="p-4"><span class="font-code-md text-code-md bg-surface-dim px-2 py-0.5 rounded text-outline">{{ f.split('.')[-1].upper() }}</span></td>
<td class="p-4">
<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-data-highlight border border-secondary text-secondary">
<span class="w-1.5 h-1.5 rounded-full bg-secondary"></span> Ready
</span>
</td>
<td class="p-4 text-right">
<div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
<a href="/download/{{ f }}" class="p-1.5 text-on-surface-variant hover:text-primary rounded hover:bg-primary-fixed transition-colors" title="Download">
<span class="material-symbols-outlined text-[18px]">download</span>
</a>
</div>
</td>
</tr>
{% endfor %}
"""

new_content = content[:start_idx] + jinja_row + content[end_idx:]
history_file.write_text(new_content)
print("History updated.")
