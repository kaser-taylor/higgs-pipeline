import pandas as pd
import uproot

with uproot.open('data_sets/DAOD_PHYSLITE.37001626._000011.pool.root.1') as file:
    tree = file['CollectionTree']
    print(tree.keys())

# file = uproot.open('data_sets/DAOD_PHYSLITE.37001626._000011.pool.root.1')
# tree = file['CollectionTree']

# features = [
#         'DER_mass_transverse_met_lep',
#         'DER_mass_vis', 'DER_pt_h', 'DER_deltaeta_jet_jet', 'DER_mass_jet_jet',
#         'DER_prodeta_jet_jet', 'DER_deltar_tau_lep', 'DER_pt_tot', 'DER_sum_pt',
#         'DER_pt_ratio_lep_tau',
#         'DER_lep_eta_centrality',
#         'PRI_lep_pt', 'PRI_lep_eta', 'PRI_lep_phi', 'PRI_met', 'PRI_met_phi', 'PRI_jet_num', 'PRI_jet_leading_pt',
#         'PRI_jet_leading_eta', 'PRI_jet_leading_phi', 'PRI_jet_subleading_pt',
#         'PRI_jet_subleading_eta', 'PRI_jet_subleading_phi', 'PRI_jet_all_pt',
#       ]

# df = tree.arrays(features, library='pd')

# print(df.columns)