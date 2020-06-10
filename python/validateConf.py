import yaml, json
from jsonschema import validate
#pip install jsonschema
if __name__ == '__main__':
    with open("/opt/hyperv-kubespray/current/infra.yaml.rendered", "r") as fichier:
        dict_to_test = yaml.load(fichier)

    with open("/opt/hyperv-kubespray/python/schema3.json", "r") as fichier:
        dict_valid = json.load(fichier)

    try:
       validate(dict_to_test,dict_valid)
    except Exception as valid_err:
        print("Validation NOK: {}".format(valid_err))
        raise valid_err
    else:
        # Realise votre travail
        print("JSON valid")


#TODO : check for odd number on etcds 