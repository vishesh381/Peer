import os
import re

DIR = "C:/Users/VisheshSharma/PeerStarDev/force-app/main/default/customMetadata"

# Map: DeveloperName -> Credible ID
id_map = {
    # Assigned Sex at Birth
    "ASAB_Male": "1284",
    "ASAB_Female": "1285",
    "ASAB_Choose_Not_To_Disclose": "1286",
    # Peer Type
    "PT_CPS": "1332",
    "PT_CRS": "1222",
    "PT_DD": "1180",
    "PT_DOC": "1181",
    "PT_Dual_Diagnosis": "1377",
    "PT_EAPS": "1229",
    "PT_eCBIT": "1184",
    "PT_Forensic_Community": "1329",
    "PT_Forensic_Jail": "1330",
    "PT_Hospital": "1183",
    "PT_Interpreter_Needed": "1186",
    "PT_JD": "1182",
    "PT_Peer_Support_CPS": "1375",
    "PT_Recovery_Support_CRS": "1376",
    "PT_Senior_Living": "1331",
    "PT_VA": "1185",
    "PT_YYA": "1378",
    # Status Reason
    "SR_001_Active": "1358",
    "SR_002_Death": "1359",
    "SR_003_Disengaged_Peer": "1360",
    "SR_004_Expired_IRP": "1361",
    "SR_005_Goals_Completed": "1362",
    "SR_017_In_Jail_Pending": "1374",
    "SR_006_Incarcerated": "1363",
    "SR_007_Inpatient": "1364",
    "SR_1388_IRP_Needs_Sched": "1382",
    "SR_1389_IRP_Scheduled": "1383",
    "SR_008_Lost_Eligibility": "1365",
    "SR_009_Peer_Moved_OOSA": "1366",
    "SR_010_Peer_Requested": "1367",
    "SR_011_Pending_Auth": "1368",
    "SR_012_Pending_CPS_CRS": "1369",
    "SR_019_Pending_Intake": "1380",
    "SR_013_Refusing_Services": "1370",
    "SR_018_Released_from_Jail": "1379",
    "SR_014_Requesting_Disch": "1371",
    "SR_015_Requesting_Staff": "1372",
    "SR_016_Scheduled_Pause": "1373",
    "SR_020_Transferred_Jail": "1381",
    # Ethnicity
    "Eth_Hispanic_or_Latino": "250",
    "Eth_Not_Hispanic": "251",
    "Eth_Unknown": "252",
    # Race
    "Race_2_African_American": "247",
    "Race_3_American_Indian": "245",
    "Race_4_Asian": "246",
    "Race_7_More_Than_One": "936",
    "Race_6_Other": "548",
    "Race_5_Pacific_Islander": "248",
    "Race_9_Unknown": "564",
    "Race_1_White": "249",
    # Preferred Contact
    "PC_HomePhone": "855",
    "PC_MobilePhone": "854",
    # Preferred Language
    "PL_Arabic": "196",
    "PL_Awadhi": "197",
    "PL_Azerbaijani_South": "198",
    "PL_Bengali": "199",
    "PL_Bhojpuri": "200",
    "PL_Burmese": "201",
    "PL_Chinese_Gan": "202",
    "PL_Chinese_Hakka": "203",
    "PL_Chinese_Jinyu": "204",
    "PL_Chinese_Mandarin": "205",
    "PL_Chinese_Min_Nan": "206",
    "PL_Chinese_Wu": "207",
    "PL_Chinese_Xiang": "208",
    "PL_Chinese_Cantonese": "209",
    "PL_Dutch": "210",
    "PL_English": "211",
    "PL_French": "212",
    "PL_German": "213",
    "PL_Gujarati": "214",
    "PL_Hausa": "215",
    "PL_Hindi": "216",
    "PL_Italian": "217",
    "PL_Japanese": "218",
    "PL_Javanese": "219",
    "PL_Kannada": "220",
    "PL_Korean": "221",
    "PL_Maithili": "222",
    "PL_Malayalam": "223",
    "PL_Marathi": "224",
    "PL_Oriya": "225",
    "PL_Panjabi_Eastern": "226",
    "PL_Panjabi_Western": "227",
    "PL_Persian": "228",
    "PL_Polish": "229",
    "PL_Portuguese": "230",
    "PL_Romanian": "231",
    "PL_Russian": "232",
    "PL_Serbo_Croatian": "233",
    "PL_Sindhi": "234",
    "PL_Spanish": "235",
    "PL_Sunda": "236",
    "PL_Tamil": "237",
    "PL_Telugu": "238",
    "PL_Thai": "239",
    "PL_Turkish": "240",
    "PL_Ukrainian": "241",
    "PL_Urdu": "242",
    "PL_Vietnamese": "243",
    "PL_Yoruba": "244",
    # Gender Identity
    "GI_Choose_Not_Disclose": "1283",
    "GI_Female": "1278",
    "GI_Genderqueer": "1281",
    "GI_Male": "1277",
    "GI_Other": "1282",
    "GI_Trans_Female_MTF": "1280",
    "GI_Trans_Male_FTM": "1279",
    # Sexual Orientation
    "SO_Bisexual": "766",
    "SO_Choose_Not_Disclose": "764",
    "SO_Dont_Know": "767",
    "SO_Lesbian_Gay": "762",
    "SO_Something_Else": "763",
    "SO_Straight": "765",
    # Preferred Pronouns
    "PP_He_Him": "1287",
    "PP_Other": "1290",
    "PP_She_Her": "1288",
    "PP_They_Them": "1289",
    # Signature Source Code
    "SS_P": "54",
    "SS_C": "52",
    "SS_S": "55",
    "SS_M": "53",
    "SS_B": "51",
    # Release Information Code
    "RI_A": "56",
    "RI_I": "57",
    "RI_O": "59",
    "RI_M": "58",
    "RI_Y": "60",
    # Bullying Last Occurrence
    "BL_1": "1264",
    "BL_3": "1266",
    "BL_2": "1265",
    "BL_4": "1267",
    "BL_0": "1263",
    # Forensic Status
    "FS_Active_Community": "1089",
    "FS_NO": "1088",
    "FS_No_Longer_Forensic": "1090",
    # Smoking Status
    "SM_0": "293",
    "SM_1": "292",
    "SM_2": "291",
    "SM_3": "294",
    "SM_4": "290",
    "SM_5": "295",
    "SM_6": "964",
    # Referral Source
    "RS_CaseManager": "1300",
    "RS_15_CommunityAction": "1015",
    "RS_19_CountyBHID": "1019",
    "RS_10_Crisis": "1010",
    "RS_28_CRS": "1187",
    "RS_11_DAProvider": "1011",
    "RS_Director": "1204",
    "RS_25_DOC": "1025",
    "RS_7_DropInClubhouse": "1007",
    "RS_12_FamilyFriend": "1012",
    "RS_9_InpatientHospital": "1009",
    "RS_16_JailDiversion": "1016",
    "RS_8_JailReentry": "1008",
    "RS_21_LTSR": "1021",
    "RS_23_OVR": "1023",
    "RS_20_ParoleProbation": "1020",
    "RS_5_PCP": "1005",
    "RS_2_PeerstarStaff": "1002",
    "RS_13_PersonalCareHome": "1013",
    "RS_PreviousPeer": "1272",
    "RS_22_PsychRehab": "1022",
    "RS_6_Psychiatrist": "1006",
    "RS_26_RTTurn": "1026",
    "RS_1_Self": "1001",
    "RS_17_Shelter": "1017",
    "RS_SocialWorker": "1301",
    "RS_SupportCoordinator": "1205",
    "RS_18_SupportProvider": "1018",
    "RS_4_Therapist": "1004",
    "RS_14_TreatmentCourt": "1014",
    "RS_24_VA": "1024",
    # Referring Qualifiers
    "RQ_G2": "1099",
    # No Admit Reason
    "NA_IneligibleMedicaid": "1157",
    "NA_NoForensicDelco": "1175",
    "NA_PeerCannotBeReached": "1160",
    "NA_PeerNoMHDiagnosis": "1172",
    "NA_PeerHasOtherSvcs": "1163",
    "NA_PeerPrivateInsurance": "1158",
    "NA_PeerInDASvcs": "1166",
    "NA_PeerInRehab": "1162",
    "NA_PeerIncarcerated": "1170",
    "NA_PeerAnotherPSS": "1164",
    "NA_PeerNotAppropriate": "1171",
    "NA_PeerOutOfArea": "1167",
    "NA_PeerNoLongerWants": "1159",
    "NA_PeerRefusedEval": "1174",
    "NA_PeerUnableScript": "1173",
    "NA_PeerWentInpatient": "1161",
    "NA_PeerWentAnotherPSS": "1165",
    "NA_PeersMANoPSS": "1169",
    "NA_PeersMAInactive": "1168",
    # Domain Focus Area Scores
    "DF_0": "1135",
    "DF_1": "1136",
    "DF_2": "1137",
    "DF_3": "1138",
    "DF_4": "1139",
    "DF_5": "1140",
    # Staff Peer Involvement
    "SP_No_Declined": "1257",
    "SP_Yes_See_ROIs": "1256",
    # Employment Status
    "ES_EmployedFT": "995",
    "ES_EmployedPT": "994",
    "ES_LOA": "1248",
    "ES_NotEmployed": "993",
    "ES_Other": "1000",
    "ES_SeasonalEmployment": "997",
    "ES_SeekingEmployment": "998",
    "ES_Student": "999",
    "ES_Suspension": "1291",
    "ES_Volunteer": "996",
}

count = 0
for devname, new_id in id_map.items():
    filepath = os.path.join(DIR, f"pstar__Credible_Field_Mapping.{devname}.md-meta.xml")
    if not os.path.exists(filepath):
        print(f"WARNING: File not found: {devname}")
        continue

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace the Credible_Code value using regex
    # Pattern: find the pstar__Credible_Code__c field block and replace its value
    pattern = r'(<field>pstar__Credible_Code__c</field>\s*<value xsi:type="xsd:string">)[^<]*(</value>)'
    new_content = re.sub(pattern, rf'\g<1>{new_id}\g<2>', content)

    if new_content != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        count += 1
    else:
        print(f"WARNING: No change for {devname}")

print(f"Updated {count} of {len(id_map)} records with Credible IDs.")
