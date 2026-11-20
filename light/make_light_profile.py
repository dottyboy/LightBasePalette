#!/usr/bin/env python3
"""Izradi "Light profil" CodeTyphona: zasebna mapa postavki (--pcp) u kojoj paleta pokazuje samo
osnovne stranice i nase stranice (TyphAccess), bez stotina ostalih.

Upotreba:  make_light_profile.py [izvor=~/.typhon64] [odrediste=~/.typhon-light]
Ne dira izvornu mapu. Pokretanje: typhon-light.sh"""
import os, shutil, sys
import xml.etree.ElementTree as ET

SRC = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else '~/.typhon64')
DST = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else '~/.typhon-light')

# stranice palete koje ostaju (redom)
KEEP = ['TyphAccess', 'Standard', 'Additional', 'Common Controls',
        'Data Controls', 'Data Access', 'Dialogs']

# sve stranice palete koje CodeTyphon i njegovi paketi poznaju (iz RegisterComponents poziva); skriva se sve osim KEEP
ALL = """Abbrevia|ACS I/O|ACS Processing|ActiveX|AggMod|AggPas|AIAssistant|Android Bridges|Android Bridges AppCompat|
Android Bridges Custom|Android Bridges Extra|Android Bridges jCenter|Android FPC|ASIO/VST Basics|ASIO/VST DSP|ASIO/VST GUI|
ASIO/VST GUI Stitched|ASIO/VST Modular|Astronomy|Barcodes|BarcodesDB|BaseControls|BGRA Controls|BGRA Extra|BGRA Shapes|
BGRA ShapesObjects|BGRA Themes|BGRA TyControls|BGRA TyControls Bars|BGRA TyControls Buttons|BGRA TyControls Choices|
BGRA TyControls Containers|BGRA TyControls Data Views|BGRA TyControls Dialogs|BGRA TyControls Edits|BGRA TyControls Gauges|
BGRA TyControls Images|BGRA TyControls Labels|BGRA TyControls Lists|BGRA TyControls Menus|BGRA TyControls Pickers|
BGRA TyControls Ribbon|BGRA TyControls Shapes & Charts|Black Shark viewport|Brook Brokers|Brook Core|CADSys|Ceos|ChatCtrl|
Chromium|ChromiumEmbed|ColorLib|Custom Drawn|Data Export|DataPort|Docking|DSP Base|DSP FiltersFIR|DSP FiltersIIR|
DSP FreqAnalisys|Equations|Extra Compress|Extra Database|Extra Design|Extra Geographic|ExtTabCtrl|Fortes Report|FPReport|
FpWeb Base|FpWeb Database|FWControls|FZControls|FZControls DB|GaiaGIS|GeoGIS|GLScene|GLScene PFX|GLScene Python|
GLScene Shaders|GLScene Terrain|GLScene Utils|GLS ROPS|Google API 1|Google API 2|Google API 3|Google API 4|Graphics32 Base|
Graphics32 Extra|Graphics32 Magic|GridPrinter|HtmlViewer|Image32 Panels|Industrial|Indy Super Core|Indy TaurusTLS|IPro|
jsGUI Base|jsGUI Bulma|jsGUI Controls|jsGUI Data Access|jsGUI Data Controls|JVCL|JVCL APP|JVCL CMP|JVCL DB|JVCL DSG|JVCL MM|
JVCL NET|JVCL PAGE|JVCL SIM|JVCL TIME|JVCL VAL|JVCL Wizard|JVCL XP|KContols|LNet|LockBox|LR Tools|LuiControls REST|
MagicScript|MiniControls|Misc|mORMot2|MPV|Multimedia|OnGuard|OpenCV|OpenGL|OpenGPSX|OpenWeather|ORCA|Orpheus|OSMMap|
Pascal Script|Pascal Type|PasDoc|PDFium|Pixie|PowerPdf|Python|Reports|RichText|RTTI|RX|RX DBAware|RX Tools|Samples|Shapes|
Shapes Objects|SimpleGraph|Skia|Solutions|SpkToolbar|Spreadsheet|SQL DB 1|SQL DB 2|SQL DB 3|SQL DB 4|SQL DB Rest|
SynapseVS|SynEdit|SynEdit Extra|System|TitanScripter|TitanSound|TyControls...|UIB|uSMBIOS|Virtual Controls|
Virtual Controls DB|Visual PlanIt|Win_API_Media|Win_DSPack|Win_MIDI|Win_WebView|Win_WMI ActiveX|Win_WMI Hardware|
Win_WMI Software|ZReport|Zeos Access|Zeos Database|Zeos Components""".replace('\n', '').split('|')
# stranice koje IDE stvarno ima (izvoz palete iz IDE-a: Settings > Options > Component Palette > Export)
EXTRA = [
    'BGRA Controls 1',
    'BGRA Controls 2',
    'BGRA Controls 3',
    'Chart',
    'Cindy Base',
    'Cindy Base Adv',
    'Cindy Base Edit',
    'Cindy Data Non-Visual',
    'Cindy Data Visual',
    'Cindy Non-Visual',
    'DCP Ciphers',
    'DCP Hashes',
    'ECControls',
    'Extra Avionics',
    'Extra Chemical',
    'Extra Controls 1',
    'Extra Controls 2',
    'Extra Controls 3',
    'Extra Controls 4',
    'Extra Controls 5',
    'Extra Controls 6',
    'Extra Special',
    'Extra System',
    'Firebird',
    'Firebird Admin',
    'Firebird Data Controls',
    'Firebird Legacy Admin',
    'FreeSpider',
    'Fundamentals',
    'Graphics32 MiniGlue',
    'Indy Clients - Core',
    'Indy Clients Protocols (am)',
    'Indy Clients Protocols (nz)',
    'Indy I/O Handlers - Core',
    'Indy I/O Handlers Protocols',
    'Indy Intercepts - Core',
    'Indy Intercepts Protocols',
    'Indy Misc - Core',
    'Indy Misc Protocols',
    'Indy Misc Protocols Decoder',
    'Indy Misc Protocols Encoder',
    'Indy SASL Protocols',
    'Indy Servers - Core',
    'Indy Servers Mapped Port',
    'Indy Servers Protocols (am)',
    'Indy Servers Protocols (nz)',
    'JPPack',
    'Jujibo',
    'Jujibo DB',
    'LuiControls',
    'LuiControls DB',
    'MapViewer',
    'PascalSCADA Database',
    'PascalSCADA FreePascal',
    'PascalSCADA HCl',
    'PascalSCADA Ports',
    'PascalSCADA Protocols',
    'PascalSCADA Tags',
    'PascalSCADA User Management',
    'PascalSCADA Utils',
    'RESTDataware-API',
    'RESTDataware-Authenticators',
    "RESTDataware-Client's",
    'RESTDataware-DB',
    'RESTDataware-Drivers',
    'RESTDataware-Service',
    'RESTDataware-Tools',
    'UserControl',
    'ZMSql'
]
HIDDEN = [p for p in dict.fromkeys(ALL + EXTRA) if p and p not in KEEP]

# datoteke postavki koje se kopiraju (ostalo se stvara iznova: povijest, sjednice)
COPY = ['environmentoptions.xml', 'packagefiles.xml', 'includelinks.xml', 'fpcdefines.xml', 'codetoolsoptions.xml',
        'editoroptions.xml', 'TyphonBuildMacros.xml', 'staticpackages.inc', 'ctcsettings.ini', 'miscellaneousoptions.xml',
        'helpoptions.xml', 'compilertest.pas', 'codetemplates.dci', 'jcfsettings.cfg', 'ide_indentation.pas',
        'debuggeroptions.xml', 'codeexploreroptions.xml']

def main():
    if not os.path.isdir(SRC):
        sys.exit('Nema izvorne mape postavki: ' + SRC)
    os.makedirs(DST, exist_ok=True)
    for f in COPY:
        p = os.path.join(SRC, f)
        if os.path.exists(p):
            shutil.copy2(p, os.path.join(DST, f))
    envp = os.path.join(DST, 'environmentoptions.xml')
    tree = ET.parse(envp)
    root = tree.getroot()
    ds = root.find('Desktops')
    if ds is None:
        sys.exit('environmentoptions.xml nema <Desktops>')
    for d in list(ds):
        old = d.find('ComponentPaletteOptions')
        if old is not None:
            d.remove(old)
        cp = ET.SubElement(d, 'ComponentPaletteOptions')
        ET.SubElement(cp, 'Name').set('Value', 'TyphAccess Light')
        pages = ET.SubElement(cp, 'Pages'); pages.set('Count', str(len(KEEP)))
        for i, n in enumerate(KEEP, 1):
            ET.SubElement(pages, 'Item%d' % i).set('Value', n)
        hid = ET.SubElement(cp, 'HiddenPages'); hid.set('Count', str(len(HIDDEN)))
        for i, n in enumerate(HIDDEN, 1):
            ET.SubElement(hid, 'Item%d' % i).set('Value', n)
    # povijest zadnjih datoteka i projekata se ne prenosi; IDE se otvara bez zadnjeg projekta
    for rec in root.iter('Recent'):
        for grp in rec:
            for c in list(grp):
                grp.remove(c)
            grp.set('Count', '0')
    for a in root.iter('AutoSave'):
        a.set('LastSavedProjectFile', '')
    tree.write(envp, encoding='UTF-8', xml_declaration=True)
    print('Light profil: ' + DST + ' (stranice: ' + ', '.join(KEEP) + '; skriveno ' + str(len(HIDDEN)) + ')')

main()
