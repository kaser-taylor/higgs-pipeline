# line 1 code

import uproot, awkward as ak, numpy as np, vector as vec

# line 1 explanation, research, and validation

uprot reads root files, awkward handles jagged, per-event variable length collections, numpy for math, vector gives a vector operations interface

awkward library: This libary is like numpy but for awkward data. It is best used for data where one row != one measurement. This library allows you to do math fast on arrays that are different sizes quickly

vector library: First a vector is a mathematical object that possesses both magnitude (length) and direction. In this branch of physics there are a lot of measurements and data types that contain 3 - 4 vectors. What this library does is allow you to process the math in an effecient and effective way without having to rewrite it every time. GPT brough up lorentz a lot so I am linking a video to lorentz transformations. https://www.youtube.com/watch?v=Rh0pYtQG5wI 


# line 2 code

vec.register_awkward()

# line 2 explanation

This line allows the math and classes behind the vector library to live inside the awkward arrays and data structures. Without registering it awkward wouldn't know how to do math on these data types

# line 4 code
GEV = 1000.0

# line 4 explanation

Particles in the accelerator and their energies are typically measured in MeV and sometimes eV. The kaggle data set uses GeV and the collider uses MeV so this line allows us to do unit conversions later down the line

quotes from gpt for this logic:

ATLAS stores kinematic measurements—like momenta, energies, invariant masses—in MeV by default. That includes things like transverse momentum (pt), energy (E), and mass. When they publish results—say, the W boson mass—they often quote it in MeV, e.g., 80 370 ± 19 MeV 
home.cern
.

And yes, it's infuriating: in your ROOT files or official ATLAS open data sets, everything is MeV unless explicitly stated otherwise. It’s like they’re daring you to forget that tiny "M" at the end and feed your model values that are 1000× too big. Because why make your life easier? https://home.cern/news/news/experiments/atlas-releases-first-measurement-w-mass-using-lhc-data?utm_source=chatgpt.com 

Kaggle’s “Higgs Boson Machine Learning Challenge” uses simulated ATLAS data—but whoever packaged it had mercy on you: they typically convert things into GeV. Many Kaggle notebooks, tutorials, and discussions around that competition implicitly treat features—like pt and mass—as GeV. Unfortunately the documentation rarely says so explicitly, but common sense says they wouldn’t expect you to wrestle with MeV in a data science contest—so they likely downscaled everything.



# line 6 and 7
with uproot.open("your_file.root") as f:
    t = f["CollectionTree"]  # adjust to actual tree name

# line 6 and 6 explanation

These lines open the file and set t to the section of the file that contains the data. If I get a key error it means the data is named something else

# line 9 - 28 code

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

# line 9-28 explanation

This line gathers all of the primary features we will need for our transformation. We are grabbing taus because the ml model looks for tau tau decay. While they are not strictly tau's they are visible tau decay products that are reconstructed as tau particles. It then grabs muons and electons because in higgs decay one of the tau's decays into a light lepton like a electron or muon. We then grab jets which help the model differentiate background and signal data. MET and Optional cleaning allow us to further differentiate good runs and background signal

Important note about this section:

I used tiered gpt chats to avoid context rot and one of the lower tiers points to an error in the type of tau data that is used. I won't be able to validate this until I run the cleaning script and inference but it will most likely change. 

# line 30

def gev(x): return x/GEV

# line 30 explanation 

This line converts MeV to Gev everywhere it exists because the ML model runs on GeV


# line 33 code

# Basic masks
good_evt = (arr["EventInfoAuxDyn.DFCommonJets_eventClean_LooseBad"] == 0) | ak.is_none(arr["EventInfoAuxDyn.DFCommonJets_eventClean_LooseBad"])

# line 33 explanation

This is line is a pre-screener for the data before it is used. If something was noticeably wrong with the jets or detector it gets a non zero value. All data with a non-zero value should be discared. In a lower tier chat it points out we never pass this as an argument so it never gets sorted so I will add that to the code *Add this tomorrow*

# line 35

arr = arr[good_evt]

# line 35 explanation 

This line slices the data and implements the pre-screener to make sure only valid data is kept. 

# line 37-43

taus = ak.zip({
    "pt":  gev(arr["AnalysisTauJetsAuxDyn.pt"]),
    "eta": arr["AnalysisTauJetsAuxDyn.eta"],
    "phi": arr["AnalysisTauJetsAuxDyn.phi"],
    "m":   gev(arr["AnalysisTauJetsAuxDyn.m"]),
    "passid": ak.values_astype(arr["AnalysisTauJetsAuxDyn.JetDeepSetLoose"], bool)
})

# line 37-43 explanation 

ak.zip converts the tau information into awkward record array. This helps group the data into multiple fields inside one object
the fields are then passed in as argumente and some of the fields like pt and m which have energy like quantities call the gev helper function to do the unit conversion.

the final line makes sure that tau values which normally come in 0 or 1 for true or false are converted to boolean true false to ensure theres no python bugs later

# line 44

taus = taus[(taus.pt > 25) & (abs(taus.eta) < 2.5) & taus.passid]

# line 44 explanation

The next line further prunes our acceptable tau's. We look for a transverse momentum higher than 25 because tau's are heavy particles and need to travel far. if we use a lower transverse momentum this includes leptons that aren't the kind we're looking for. this is indicated in the taus.pt > 25. the next bit taus.eta limits how much of the detector we look at. As you get farther from the center of the detector the resolution of the data lowers and may provide an innaccurate picture so this allows us to have a good resolution. the last line keeps tau's that pass a built in ml classifier that throws out noise or bad leptons. 


# line 46-51
mus = ak.zip({
    "pt":  gev(arr["AnalysisMuonsAuxDyn.pt"]),
    "eta": arr["AnalysisMuonsAuxDyn.eta"],
    "phi": arr["AnalysisMuonsAuxDyn.phi"],
    "passid": ak.values_astype(arr["AnalysisMuonsAuxDyn.DFCommonMuonPassPreselection"], bool)
})

# line 46-51 explanation

This section is pretty similar to the tau section but is focused on Muons. The first like converts the transverse momemntum into GeV. The second line grabs the pseudorapidity which is the angle from the beam and the third grabs azimuthal angle which is which direction in the cylinder it went. the final line is the baseline preselection like with taus that tells us if the data is valid

# line 52
mus = mus[(mus.pt > 20) & (abs(mus.eta) < 2.5) & mus.passid]

# line 52 explanation

This is similar to line 44 but is shortens the depth of the detector because muons are lighter and don't travel as far. 


# line 54 - 61

els = ak.zip({
    "pt":  gev(arr["AnalysisElectronsAuxDyn.pt"]),
    "eta": arr["AnalysisElectronsAuxDyn.eta"],
    "phi": arr["AnalysisElectronsAuxDyn.phi"],
    "passid": ak.values_astype(arr["AnalysisElectronsLHMedium"], bool)  # alias if needed
}, with_name="Momentum4D")  # optional

els = els[(els.pt > 20) & (abs(els.eta) < 2.47) & els.passid]

# line 54 - 61 explanation

This is the same as the last two sections but for electrons. The detector range is shortened slightly as well because electrons are lighter and don't travel as far

# Choose exactly one lepton: highest-pt among e/mu
both = ak.concatenate([els, mus], axis=1)
lep = both[ak.singletons(ak.argmax(both.pt, axis=1, keepdims=False))]
lep = ak.firsts(lep)

# One tau: highest pt
tau = ak.firsts(taus[ak.singletons(ak.argmax(taus.pt, axis=1))])

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
