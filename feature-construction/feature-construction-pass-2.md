# About
## As I went through the feature construction the first time with different gpt chats to understand the code it found errors. This file modifies the code with notes on why. 

import uproot, awkward as ak, numpy as np, vector as vec
vec.register_awkward()

GEV = 1000.0

with uproot.open("your_file.root") as f:
    t = f["CollectionTree"]  # adjust to actual tree name

# remember to look at the keys and change this 

    arr = t.arrays([
        # Taus
        "AnalysisTauJetsAuxDyn.pt", "AnalysisTauJetsAuxDyn.eta",
        "AnalysisTauJetsAuxDyn.phi", "AnalysisTauJetsAuxDyn.m",
        "AnalysisTauJetsAuxDyn.JetDeepSetLoose",  # or use RNN scores
        # Muons
        "AnalysisMuonsAuxDyn.pt","AnalysisMuonsAuxDyn.eta",
        "AnalysisMuonsAuxDyn.phi","AnalysisMuonsAuxDyn.DFCommonMuonPassPreselection",
        # Electrons
        "AnalysisElectronsAuxDyn.pt","AnalysisElectronsAuxDyn.eta",
        "AnalysisElectronsAuxDyn.phi","AnalysisElectronsAuxDyn.DFCommonElectronsLHMedium",
        # Jets
        "AnalysisJetsAuxDyn.pt","AnalysisJetsAuxDyn.eta",
        "AnalysisJetsAuxDyn.phi","AnalysisJetsAuxDyn.m",
        "AnalysisJetsAuxDyn.DFCommonJets_isBadBatman",
        # MET
        "MET_Core_AnalysisMETAuxDyn.mpx","MET_Core_AnalysisMETAuxDyn.mpy",
        # Optional cleaning
        "EventInfoAuxDyn.DFCommonJets_eventClean_LooseBad"
    ], library="ak")

def gev(x): return x/GEV

# Basic masks
good_evt = (arr["EventInfoAuxDyn.DFCommonJets_eventClean_LooseBad"] == 0) | ak.is_none(arr["EventInfoAuxDyn.DFCommonJets_eventClean_LooseBad"])

arr = arr[good_evt]

taus = ak.zip({
    "pt":  gev(arr["AnalysisTauJetsAuxDyn.pt"]),
    "eta": arr["AnalysisTauJetsAuxDyn.eta"],
    "phi": arr["AnalysisTauJetsAuxDyn.phi"],
    "m":   gev(arr["AnalysisTauJetsAuxDyn.m"]),
    "passid": ak.values_astype(arr["AnalysisTauJetsAuxDyn.JetDeepSetLoose"], bool)
})
taus = taus[(taus.pt > 25) & (abs(taus.eta) < 2.5) & taus.passid]

mus = ak.zip({
    "pt":  gev(arr["AnalysisMuonsAuxDyn.pt"]),
    "eta": arr["AnalysisMuonsAuxDyn.eta"],
    "phi": arr["AnalysisMuonsAuxDyn.phi"],
    "passid": ak.values_astype(arr["AnalysisMuonsAuxDyn.DFCommonMuonPassPreselection"], bool)
})
mus = mus[(mus.pt > 20) & (abs(mus.eta) < 2.5) & mus.passid]

els = ak.zip({
    "pt":  gev(arr["AnalysisElectronsAuxDyn.pt"]),
    "eta": arr["AnalysisElectronsAuxDyn.eta"],
    "phi": arr["AnalysisElectronsAuxDyn.phi"],
    "passid": ak.values_astype(arr["AnalysisElectronsAuxDyn.DFCommonElectronsLHMedium"], bool)  # alias if needed
# wrong key name changed here line 61    
}, with_name="Momentum4D")  # optional

els = els[(els.pt > 20) & (abs(els.eta) < 2.47) & els.passid]

# Choose exactly one lepton: highest-pt among e/mu
# edit making sure theres an electron an a muon

have_lep = (ak.num(els) + ak.nums(mus)) > 0
els = els[have_lep]
mus = mus[have_lep]

both = ak.concatenate([els, mus], axis=1)
lep  = ak.firsts(both[ak.singletons(ak.argmax(both.pt, axis=1))])
# adds a safety for the els and muons to make sure we have enough 

# One tau: highest pt
have_tau = ak.num(taus) > 0
taus = taus[have_tau]
tau  = ak.firsts(taus[ak.singletons(ak.argmax(taus.pt, axis=1))])

# same deal here  as the els and mus
# Jets
jets = ak.zip({
    "pt":  gev(arr["AnalysisJetsAuxDyn.pt"]),
    "eta": arr["AnalysisJetsAuxDyn.eta"],
    "phi": arr["AnalysisJetsAuxDyn.phi"],
    "m":   gev(arr["AnalysisJetsAuxDyn.m"]),
    "bad": ak.values_astype(arr["AnalysisJetsAuxDyn.DFCommonJets_isBadBatman"], bool)
})
jets = jets[(jets.pt > 30) & (abs(jets.eta) < 4.5) & (~jets.bad)]
jets = jets[ak.argsort(jets.pt, ascending=False)]
j1 = ak.firsts(jets)
j2 = ak.firsts(ak.pad_none(jets, 2)[:,1])

# MET
mpx = gev(arr["MET_Core_AnalysisMETAuxDyn.mpx"])
mpy = gev(arr["MET_Core_AnalysisMETAuxDyn.mpy"])
met = np.sqrt(mpx*mpx + mpy*mpy)
met_phi = np.arctan2(mpy, mpx)

# Four-vectors
def p4(o):
    return vec.obj(pt=o.pt, eta=o.eta, phi=o.phi, mass=ak.fill_none(o.m if "m" in o.fields else 0, 0))

lep4 = vec.obj(pt=lep.pt, eta=lep.eta, phi=lep.phi, mass=0)  # approx massless
tau4 = p4(tau)
j14  = p4(j1)
j24  = p4(j2)

# Helper
def dphi(phi1, phi2):
    d = phi1 - phi2
    return np.arctan2(np.sin(d), np.cos(d))

# PRI_*
PRI_lep_pt  = lep.pt
PRI_lep_eta = lep.eta
PRI_lep_phi = lep.phi
PRI_met     = met
PRI_met_phi = met_phi
PRI_jet_num = ak.num(jets)
PRI_jet_leading_pt  = ak.fill_none(j1.pt,  -999)
PRI_jet_leading_eta = ak.fill_none(j1.eta, -999)
PRI_jet_leading_phi = ak.fill_none(j1.phi, -999)
PRI_jet_subleading_pt  = ak.fill_none(j2.pt,  -999)
PRI_jet_subleading_eta = ak.fill_none(j2.eta, -999)
PRI_jet_subleading_phi = ak.fill_none(j2.phi, -999)
PRI_jet_all_pt = ak.sum(jets.pt, axis=1)

# DER_*
DER_mass_transverse_met_lep = np.sqrt(2*PRI_lep_pt*PRI_met*(1 - np.cos(dphi(PRI_lep_phi, PRI_met_phi))))
DER_mass_vis = (lep4 + tau4).mass
DER_pt_h = np.hypot( (lep4.px + tau4.px + met*np.cos(met_phi)),
                     (lep4.py + tau4.py + met*np.sin(met_phi)) )

DER_deltar_tau_lep = np.hypot(lep4.eta - tau4.eta, dphi(lep4.phi, tau4.phi))

# Build pt vectors for sum
def px(pt,phi): return pt*np.cos(phi)
def py(pt,phi): return pt*np.sin(phi)

# Use up to 2 jets for Kaggle-like behavior
sum_px = lep4.px + tau4.px + ak.fill_none(j14.px, 0) + ak.fill_none(j24.px, 0) + met*np.cos(met_phi)
sum_py = lep4.py + tau4.py + ak.fill_none(j14.py, 0) + ak.fill_none(j24.py, 0) + met*np.sin(met_phi)
DER_pt_tot = np.hypot(sum_px, sum_py)

DER_sum_pt = PRI_lep_pt + tau4.pt + ak.fill_none(j14.pt,0) + ak.fill_none(j24.pt,0) + PRI_met

has2 = ak.is_none(j2.pt) == False
DER_deltaeta_jet_jet = ak.where(has2, np.abs(j14.eta - j24.eta), -999)
DER_mass_jet_jet     = ak.where(has2, (j14 + j24).mass, -999)
DER_prodeta_jet_jet  = ak.where(has2, j14.eta * j24.eta, -999)
DER_lep_eta_centrality = ak.where(
    has2,
    2*(lep4.eta - 0.5*(j14.eta + j24.eta)) / np.abs(j14.eta - j24.eta),
    -999
)

DER_pt_ratio_lep_tau = ak.where(tau4.pt > 0, PRI_lep_pt / tau4.pt, -999)

# Now package into a pandas DataFrame if you want
import pandas as pd
df = pd.DataFrame({
    "DER_mass_transverse_met_lep": ak.to_numpy(DER_mass_transverse_met_lep),
    "DER_mass_vis": ak.to_numpy(DER_mass_vis),
    "DER_pt_h": ak.to_numpy(DER_pt_h),
    "DER_deltaeta_jet_jet": ak.to_numpy(DER_deltaeta_jet_jet),
    "DER_mass_jet_jet": ak.to_numpy(DER_mass_jet_jet),
    "DER_prodeta_jet_jet": ak.to_numpy(DER_prodeta_jet_jet),
    "DER_deltar_tau_lep": ak.to_numpy(DER_deltar_tau_lep),
    "DER_pt_tot": ak.to_numpy(DER_pt_tot),
    "DER_sum_pt": ak.to_numpy(DER_sum_pt),
    "DER_pt_ratio_lep_tau": ak.to_numpy(DER_pt_ratio_lep_tau),
    "DER_lep_eta_centrality": ak.to_numpy(DER_lep_eta_centrality),
    "PRI_lep_pt": ak.to_numpy(PRI_lep_pt),
    "PRI_lep_eta": ak.to_numpy(PRI_lep_eta),
    "PRI_lep_phi": ak.to_numpy(PRI_lep_phi),
    "PRI_met": ak.to_numpy(PRI_met),
    "PRI_met_phi": ak.to_numpy(PRI_met_phi),
    "PRI_jet_num": ak.to_numpy(PRI_jet_num),
    "PRI_jet_leading_pt": ak.to_numpy(PRI_jet_leading_pt),
    "PRI_jet_leading_eta": ak.to_numpy(PRI_jet_leading_eta),
    "PRI_jet_leading_phi": ak.to_numpy(PRI_jet_leading_phi),
    "PRI_jet_subleading_pt": ak.to_numpy(PRI_jet_subleading_pt),
    "PRI_jet_subleading_eta": ak.to_numpy(PRI_jet_subleading_eta),
    "PRI_jet_subleading_phi": ak.to_numpy(PRI_jet_subleading_phi),
    "PRI_jet_all_pt": ak.to_numpy(PRI_jet_all_pt)
})
