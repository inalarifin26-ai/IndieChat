"""Assembles the single-file interactive preview: python3 build.py  ->  ../indie_preview.html"""
import base64, os
d = os.path.dirname(os.path.abspath(__file__)) + '/'
css = open(d + 'style.css', encoding='utf8').read(); body = open(d + 'body.html', encoding='utf8').read()
js = ''.join(open(d + f, encoding='utf8').read() + '\n' for f in ['js1_core.js', 'js2_data.js', 'js3_chat.js', 'js4_screens.js', 'js5_orch_flow.js', 'js6_voice.js'])
b64 = lambda p: 'data:image/webp;base64,' + base64.b64encode(open(p, 'rb').read()).decode()
body = body.replace('__LOGO_FULL__', b64(d + 'logo_full.webp')).replace('__LOGO_ICON__', b64(d + 'logo_icon.webp'))
html = f'<!DOCTYPE html>\n<html lang="id"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n<title>Indie — Preview</title><style>{css}</style></head>\n<body>{body}<script>{js}</script></body></html>'
open(d + '../indie_preview.html', 'w', encoding='utf8').write(html); print('wrote', len(html), 'bytes')
