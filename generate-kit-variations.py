#!python3

# Script for generating some shirt/pant color variations
# Reads *.json and writes *{1,2,4,5,6,7,8}.kit files

VARIATIONS=[
    # 1
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Green')],
    # 2
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Red')],
    # 3
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Tan')],
    # 4
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Black')],
    # 5
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Navy')],
    # 6
    [('Shirt', 'Shirt:BP_Shirt_Under', 'Red'),('Pants', 'Pants:BP_Pants_Jeans', 'Blue')],
    # 7
    [('Shirt', 'Shirt:BP_Shirt_Under', 'Navy'),('Pants', 'Pants:BP_Pants_Jeans', 'Blue')],
    # 8
    [('Shirt', 'Shirt:BP_Shirt_Under', 'Khaki'),('Pants', 'Pants:BP_Pants_Jeans', 'Blue')]
]

VARIATIONS_FOR_HVT=[
    # 1
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp_Plain', 'Black')],
    # 2
    [('Shirt', 'Shirt:BP_Shirt_ButtonUp', 'Tan')]
]

import json

def load_kit(name):
    f = open(name)
    data = json.load(f)
    f.close()
    return data

def process_file(filename_prefix, variation_list):
    i = 0
    print("Processing " + filename_prefix)
    for variation_list in variation_list:
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
    prefix_list=['Narcos/Civ', 'Narcos/Tango_AR', 'Narcos/Tango_SMG', 'Narcos/Tango_SNP', 'Narcos/Tango_STG', 'Narcos/Tango_HDG']
    for filename_prefix in prefix_list:
        process_file('GroundBranch/Content/GroundBranch/AI/Loadouts/' + filename_prefix, VARIATIONS)
    process_file('GroundBranch/Content/GroundBranch/AI/Loadouts/Narcos/HVT_AR', VARIATIONS_FOR_HVT)

if __name__ == "__main__":
    main()
