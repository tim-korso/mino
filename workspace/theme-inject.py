"""Inject Mino brand theme colors into an existing PPTX via python-pptx XML manipulation."""
from pptx import Presentation
from lxml import etree
import sys, os

A_NS = 'http://schemas.openxmlformats.org/drawingml/2006/main'

BRAND_COLORS = {
    'dk1': '000000', 'lt1': 'FFFFFF',
    'dk2': '1A1A2E', 'lt2': 'F5F5F5',
    'accent1': 'D33941', 'accent2': '30B5C5',
    'accent3': '62B230', 'accent4': 'ED6D00',
    'accent5': '7F0001', 'accent6': '898989',
    'hlink': '30B5C5', 'folHlink': '555757',
}
BRAND_NAME = 'Mino Cognitive Gap Tracker'

def build_color_xml(name, color_map):
    """Build a:clrScheme XML element."""
    cs = etree.SubElement(etree.Element('dummy'), f'{{{A_NS}}}clrScheme')
    cs.set('name', name)
    for slot, hex_val in color_map.items():
        elem = etree.SubElement(cs, f'{{{A_NS}}}{slot}')
        srgb = etree.SubElement(elem, f'{{{A_NS}}}srgbClr')
        srgb.set('val', hex_val.upper())
    return cs

def apply_theme(pptx_path, output_path):
    prs = Presentation(pptx_path)

    # Find theme part through slide master relationships
    theme_part = None
    for sm in prs.slide_masters:
        for rel in sm.part.rels.values():
            if 'theme' in rel.reltype.lower():
                theme_part = rel.target_part
                break
        if theme_part:
            break

    if not theme_part:
        print("ERROR: No theme part found in slide masters")
        return False

    print(f"Theme part: {theme_part.partname}")
    theme_blob = theme_part.blob
    root = etree.fromstring(theme_blob)

    # Find and replace clrScheme
    clr_schemes = root.findall(f'.//{{{A_NS}}}clrScheme')
    print(f"Found {len(clr_schemes)} clrScheme(s)")

    if not clr_schemes:
        print("No clrScheme found - injecting new one")
        theme_elems = root.findall(f'.//{{{A_NS}}}themeElements')
        if theme_elems:
            new_cs = build_color_xml(BRAND_NAME, BRAND_COLORS)
            theme_elems[0].insert(0, new_cs)
    else:
        for cs in clr_schemes:
            old_name = cs.get('name', '(unnamed)')
            parent = cs.getparent()
            new_cs = build_color_xml(BRAND_NAME, BRAND_COLORS)
            parent.replace(cs, new_cs)
            print(f"  Replaced '{old_name}' -> '{BRAND_NAME}'")

    # Update theme fonts
    font_schemes = root.findall(f'.//{{{A_NS}}}fontScheme')
    if font_schemes:
        fs = font_schemes[0]
        # Set major font (East Asian)
        major_font = fs.find(f'{{{A_NS}}}majorFont')
        if major_font is not None:
            ea = major_font.find(f'{{{A_NS}}}ea')
            if ea is None:
                ea = etree.SubElement(major_font, f'{{{A_NS}}}ea')
            ea.set('typeface', 'Microsoft YaHei')
            latin = major_font.find(f'{{{A_NS}}}latin')
            if latin is None:
                latin = etree.SubElement(major_font, f'{{{A_NS}}}latin')
            latin.set('typeface', 'Arial')
        # Set minor font
        minor_font = fs.find(f'{{{A_NS}}}minorFont')
        if minor_font is not None:
            ea = minor_font.find(f'{{{A_NS}}}ea')
            if ea is None:
                ea = etree.SubElement(minor_font, f'{{{A_NS}}}ea')
            ea.set('typeface', 'Microsoft YaHei')
            latin = minor_font.find(f'{{{A_NS}}}latin')
            if latin is None:
                latin = etree.SubElement(minor_font, f'{{{A_NS}}}latin')
            latin.set('typeface', 'Arial')
        print("  Theme fonts updated: Microsoft YaHei + Arial")

    # Save modified theme XML back
    theme_part._blob = etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)

    # In-place save (overwrite input)
    prs.save(output_path)
    in_size = os.path.getsize(pptx_path)
    out_size = os.path.getsize(output_path)
    print(f"Theme injected: {output_path}")
    print(f"Size: {in_size/1024:.0f}KB -> {out_size/1024:.0f}KB (delta: {out_size - in_size:+d}B)")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: theme-inject.py <pptx_path> [output_path]")
        print("  Single arg: modifies file in-place")
        print("  Two args:   writes to output_path, preserves input")
        sys.exit(1)

    input_path = sys.argv[1]
    if len(sys.argv) > 2:
        output_path = sys.argv[2]
    else:
        output_path = input_path  # in-place

    success = apply_theme(input_path, output_path)
    sys.exit(0 if success else 1)
