import uproot

with uproot.open('data_sets/DAOD_PHYSLITE.37001626._000011.pool.root.1') as file:
    tree = file['CollectionTree']
    print(tree.keys())