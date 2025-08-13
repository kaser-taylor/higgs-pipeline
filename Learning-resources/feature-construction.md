###### This is defintions and resources I used in chronological order to do feature construction for the train_v2 model #####

# I have copy and pasted stuff straight from gpt

# p1 explanation 

Alright, let’s take the physics jargon and turn it into something your grandmother could follow over breakfast.

Think of the Higgs event like a **crime scene** in a detective show. The Higgs boson is the criminal, and it leaves behind two “calling cards” — tau particles. One tau smashes into the furniture (hadrons), the other sneaks out the back door disguised as a light lepton (electron or muon) with a couple of invisible accomplices (neutrinos).

* **τ\_h (hadronic tau)** = the tau that throws a chair, breaks a vase, and leaves messy tracks (hadronic debris).
* **Light lepton (e or μ)** = the tau that changes clothes and slips away quietly as an electron or muon.
* **Jets** = random other party crashers in the scene — small blasts of particles from quark/gluon spray.
* **MET (Missing Transverse Energy)** = the trail of the invisible neutrinos — like footprints in the snow leading nowhere.

Now the dataset has two types of clues:

* **DER\_**\* (“Derived” features) = like the detective’s crime-scene sketches and analysis — these aren’t the raw fingerprints, but measurements *calculated* from combining other pieces: angles, distances, energy sums, etc.
* **PRI\_**\* (“Primary” features) = like the raw police evidence bag — untouched measurements straight from the scene (energy, momentum) before any math wizardry.

The “channel” here is specifically looking for the case where **one tau makes a mess in the kitchen** (τ\_h) and **the other tau sneaks off as a lepton** (e/μ) — plus maybe a couple of extra troublemakers (jets). You **pick exactly one messy tau, one sneaky lepton, keep the two most suspicious jets**, and crunch the numbers.

If you wanted, I could sketch this whole thing like a little comic so you can literally “see” the crime scene. Would probably make this click instantly.

# tau particle defintion 

A tau (τ) is basically the electron’s beefy, short-lived cousin. It’s one of the six **leptons** in the Standard Model, in the same family as electrons and muons, but much heavier — about **3,500 times the mass of an electron**.

The important bits:

* **Charge:** −1 (just like the electron).
* **Spin:** ½ (so it’s a fermion).
* **Mass:** \~1.777 GeV/c², which in particle physics terms is “heavy enough to fall apart almost instantly.”
* **Lifetime:** \~3×10⁻¹³ seconds before it decays into lighter particles.
* **Interaction:** Feels the weak, electromagnetic, and gravitational forces (but not the strong force).

Because it’s so massive, the tau can decay into a variety of particles — sometimes into other leptons (like an electron or muon plus neutrinos), other times into hadrons (pions, kaons, etc.), which is why you’ll see experimental physicists talk about “hadronic taus” (τ\_h) versus “leptonic taus.”

In collider experiments like ATLAS at the LHC, taus are especially important in studying **Higgs boson decays** (H → ττ), because they give a relatively clean signature for certain channels — clean being relative, since taus love to decay into a messy spray of particles that’s fun to reconstruct if you enjoy pain.

If electrons are nimble hummingbirds and muons are beefed-up pigeons, taus are basically bowling balls that smash into the lane and shatter into a mess before you can even blink.

I can also walk you through how physicists detect taus in ATLAS and why “hadronic tau reconstruction” is so tricky. You want me to go there?

# hadron defintion

A hadron is a particle made of **quarks** that’s held together by the **strong force** — the same force that glues protons and neutrons together inside atomic nuclei.

There are two main species:

* **Baryons:** three quarks. Examples: protons (uud), neutrons (udd), and exotic heavy ones like Λ and Ω particles.
* **Mesons:** one quark and one antiquark. Examples: pions (π⁺, π⁰, π⁻), kaons (K⁺, K⁰).

The strong force is mediated by gluons, which are like unreasonably clingy friends — they not only stick quarks together, but also stick to each other, so you never see a lone quark wandering around (that’s called “color confinement”). Break a hadron apart, and you just end up making more hadrons.

The name *hadron* comes from the Greek *hadros*, meaning “thick” or “strong,” which is physicist-speak for “these particles aren’t wispy little electrons, they’re chunky and bound tight.”

In collider physics, hadrons make life messy. Smash protons together and you don’t get nice clean events — you get a **hadronic spray** (jets) as quarks and gluons fragment into more hadrons. That’s why reconstructing something like a hadronic tau decay is like trying to guess the original Lego set from a pile of loose bricks.

Do you want me to contrast hadrons with leptons so the tau/hadron thing clicks completely?

# Basic Particle Physics Video

https://youtu.be/-L5OQp2J46g?si=1JBFcC_A89xbXows

###### Summary of how the notes about relate to the simulated and root features #####

### PRI and DER features in the kaggle set

A PRI feature stands for a primary feature. This is quote on quote raw data from the collider. * There is a lot of calibration that goes on before data is submitted to the open data portal more information on that can be found here https://cds.cern.ch/record/2939534 * A DER feature is essentially an aggregate of primary features that represents a significant value. The challenge is mapping the root data to features that are compatible with the model trained on the simulated data set. The script GPT made to do the mapping is found below. In another file feature-construction-code.md in the Learning-resources folder I will do a line by line code and validation of this script citing sources I used to validate it. As much as I would like to trust GPT 5 to one shot it I do not know enough about physics to look at it and say its close enough for my use case.


##### Feature Translation Script #####

import uproot, awkward as ak, numpy as np, vector as vec
vec.register_awkward()

GEV = 1000.0

with uproot.open("your_file.root") as f:
    t = f["CollectionTree"]  # adjust to actual tree name

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
    "passid": ak.values_astype(arr["AnalysisElectronsLHMedium"], bool)  # alias if needed
}, with_name="Momentum4D")  # optional

els = els[(els.pt > 20) & (abs(els.eta) < 2.47) & els.passid]

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

