#!python3

# Script for generating some shirt/pant color variations
# Reads *1.kit and writes *{1,2,4,5,6,7,8}.kit files

VARIATIONS=[
    # 1
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Green')],
    # 2
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Red')],
    # 3
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Tan')],
    # 4
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Grey')],
    # 5
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Navy')],
    # 6
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Green'),('Pants', 'Pants:BP_Pants_Jeans', 'Black')],
    # 7
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Grey'),('Pants', 'Pants:BP_Pants_Jeans', 'Black')],
    # 8
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Tan'),('Pants', 'Pants:BP_Pants_Jeans', 'Black')]
]


PREFIX_LIST=['Civ']


import json

def load_kit(name):
    f = open(name)
    data = json.load(f)
    f.close()
    return data

def process_file(filename_prefix):
    i = 0
    print("Processing " + filename_prefix)
    for variation_list in VARIATIONS:
        i = i + 1
        data = load_kit(filename_prefix + '-template.json')

        for (type, item, skin) in variation_list:
            for obj in data['Data']:
                if obj['Type'] == 'Outfit':
                    for outfit_item in obj['Data']:
                        if outfit_item['Type'] == type:
                            outfit_item['Item'] = item
                            outfit_item['Skin'] = skin

        outfile_name = filename_prefix + str(i) + '.kit'
        print('Writing ' + outfile_name)
        with open(outfile_name, 'w', newline='\n') as outfile:
            outfile.write(json.dumps(data, indent=4))
            outfile.write("\n")

def main():
    prefix_list=['Civ', 'Tango_AR', 'Tango_SMG', 'Tango_SNP', 'Tango_STG', 'Tango_HDG']
    for filename_prefix in prefix_list:
        process_file(filename_prefix)

if __name__ == "__main__":
    main()
