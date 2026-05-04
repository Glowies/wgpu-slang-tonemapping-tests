struct OpenDrtUniforms {
  uint inGamut;
  uint inOetf;
  uint displayEncodingPreset;
  uint lookPreset;
  float displayPeakLuminance;
};

/* OpenDRT v1.1.0 -------------------------------------------------

  Written by Jed Smith
  https://github.com/jedypod/open-display-transform
  License: GPLv3
  -------------------------------------------------*/

const static float tn_gb = 0.13; // HDR Grey Boost
const static float pt_hdr = 0.5; // HDR Purity
const static float tn_Lg = 10.0; // Display Grey Luminance

const static uint tonescale_preset = 0; // Tonescale Preset
const static uint _cwp = 0;             // Creative White
const static float _cwp_lm = 0.25;      // Creative White Limit

/****
  DCTL to Slang Conversion Functions
 ******************************************************************/

float2 make_float2(float x, float y) { return float2(x, y); }

float3 make_float3(float x, float y, float z) { return float3(x, y, z); }

float3x3 make_float3x3(float3 x, float3 y, float3 z) {
  return float3x3(x, y, z);
}

float _powf(float a, float b) { return pow(a, b); }

float _sqrtf(float a) { return sqrt(a); }

float _fabs(float a) { return abs(a); }

float _expf(float a) { return exp(a); }

float _logf(float a) { return log(a); }
float _exp2f(float a) { return exp2(a); }

float _exp10f(float a) { return exp10(a); }

float _log2f(float a) { return log2(a); }

float _fmaxf(float a, float b) { return max(a, b); }

float _fminf(float a, float b) { return min(a, b); }

float _fmod(float a, float b) { return fmod(a, b); }
float _atan2f(float a, float b) {
  if (abs(a) + abs(b) < 0.000001) {
    return a * b;
  }
  return atan2(a, b);
}

// overriding the declaration below
float3 vdot(float3x3 m, float3 v) { return mul(v, transpose(m)); }

// Input settings
// DEFINE_UI_PARAMS(in_gamut, Input Gamut, DCTLUI_COMBO_BOX, 14,
//                  { i_xyz, i_ap0, i_ap1, i_p3d65, i_rec2020, i_rec709, i_awg3,
//                    i_awg4, i_rwg, i_sgamut3, i_sgamut3cine, i_vgamut,
//                    i_egamut, i_egamut2, i_davinciwg },
//                  { XYZ, ACES 2065 - 1, ACEScg, P3D65, Rec .2020, Rec .709,
//                    Arri Wide Gamut 3, Arri Wide Gamut 4, Red Wide Gamut RGB,
//                    Sony SGamut3, Sony SGamut3Cine, Panasonic V - Gamut,
//                    Filmlight E - Gamut, Filmlight E - Gamut2,
//                    DaVinci Wide Gamut })
// DEFINE_UI_PARAMS(in_oetf, Input Transfer Function, DCTLUI_COMBO_BOX, 1,
//                  { ioetf_linear, ioetf_davinci_intermediate,
//                    ioetf_filmlight_tlog, ioetf_acescct, ioetf_arri_logc3,
//                    ioetf_arri_logc4, ioetf_redlog3g10, ioetf_panasonic_vlog,
//                    ioetf_sony_slog3, ioetf_fuji_flog },
//                  { Linear, Davinci Intermediate, Filmlight T - Log, ACEScct,
//                    Arri LogC3, Arri LogC4, RedLog3G10, Panasonic V - Log,
//                    Sony S - Log3, Fuji F - Log2 })

// // Tonescale Parameters
// DEFINE_UI_PARAMS(tn_Lp, Display Peak Luminance, DCTLUI_SLIDER_FLOAT, 100.0,
//                  100.0, 1000.0, 1.0)
// DEFINE_UI_PARAMS(tn_gb, HDR Grey Boost, DCTLUI_SLIDER_FLOAT, 0.13, 0.0, 1.0,
//                  0.001)
// DEFINE_UI_PARAMS(pt_hdr, HDR Purity, DCTLUI_SLIDER_FLOAT, 0.5, 0.0, 1.0,
// 0.01) DEFINE_UI_PARAMS(tn_Lg, Display Grey Luminance,
// DCTLUI_SLIDER_FLOAT, 10.0, 3.0,
//                  25.0, 0.1)

/*--------------------------------------------------------------------------------------
  Due to the limited nature of DCTL, I've made the choice to only expose the
presets and not the full parameter space. For those of you who are too curious
for your own good and interested in experimenting...

!!! TO ENABLE STICKSHIFT MODE FOR CUSTOM LOOK CREATION:
    1. **UN-COMMENT** the lines below, including the define INIT_PARAMS line.
This enables all of the user parameters.
    2. Comment out the lines below that for the preset parameters (You can leave
them enabled, but they won't do anything)

  Tip 1: If you are using a modern text editor like VSCode,
    you can comment or un-comment multiple selected lines with Ctrl+/
  Tip 2: You can use the Nuke node to create a preset and click the "Show DCTL"
button to show code for the below with your custom parameter values. Or add your
own presets in the LOOK PRESETS section around line 464.
---------------------------------------------------------------------------------------*/

// #define INIT_PARAMS

// DEFINE_UI_PARAMS(_tn_con, Contrast, DCTLUI_SLIDER_FLOAT, 1.66, 1.0, 2.0,
// 0.01) DEFINE_UI_PARAMS(_tn_sh, Shoulder Clip, DCTLUI_SLIDER_FLOAT, 0.5,
// 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_tn_toe, Toe, DCTLUI_SLIDER_FLOAT, 0.003,
// 0.0, 0.1, 0.001) DEFINE_UI_PARAMS(_tn_off, Offset, DCTLUI_SLIDER_FLOAT,
// 0.005, 0.0, 0.02, 0.0002) DEFINE_UI_PARAMS(_tn_hcon_enable, Enable Contrast
// High, DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_tn_hcon, Contrast High,
// DCTLUI_SLIDER_FLOAT, 0.0, -1.0, 1.0, 0.02) DEFINE_UI_PARAMS(_tn_hcon_pv,
// Contrast High Pivot, DCTLUI_SLIDER_FLOAT, 1.0, 0.0, 4.0, 0.04)
// DEFINE_UI_PARAMS(_tn_hcon_st, Contrast High Strength,
// DCTLUI_SLIDER_FLOAT, 4.0, 0.0, 4.0, 0.04) DEFINE_UI_PARAMS(_tn_lcon_enable,
// Enable Contrast Low, DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_tn_lcon, Contrast
// Low, DCTLUI_SLIDER_FLOAT, 0.0, 0.0, 3.0, 0.03) DEFINE_UI_PARAMS(_tn_lcon_w,
// Contrast Low Width, DCTLUI_SLIDER_FLOAT, 0.5, 0.0, 2.0, 0.02)
// DEFINE_UI_PARAMS(_cwp, Creative White, DCTLUI_COMBO_BOX, 2, {_cwp0, _cwp1,
// _cwp2, _cwp3, _cwp4, _cwp5}, {D93, D75, D65, D60, D55, D50})
// DEFINE_UI_PARAMS(_cwp_lm, Creative White Limit, DCTLUI_SLIDER_FLOAT, 0.25,
// 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_rs_sa, Render Space Strength,
// DCTLUI_SLIDER_FLOAT, 0.35, 0.0, 0.6, 0.006) DEFINE_UI_PARAMS(_rs_rw, Render
// Space Weight R, DCTLUI_SLIDER_FLOAT, 0.25, 0.0, 0.8, 0.008)
// DEFINE_UI_PARAMS(_rs_bw, Render Space Weight B, DCTLUI_SLIDER_FLOAT, 0.55,
// 0.0, 0.8, 0.008) DEFINE_UI_PARAMS(_pt_enable, Enable Purity Compress High,
// DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_pt_lml, Purity Limit Low,
// DCTLUI_SLIDER_FLOAT, 0.25, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_pt_lml_r, Purity
// Limit Low R, DCTLUI_SLIDER_FLOAT, 0.5, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_pt_lml_g, Purity Limit Low G, DCTLUI_SLIDER_FLOAT, 0.0,
// 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_pt_lml_b, Purity Limit Low B,
// DCTLUI_SLIDER_FLOAT, 0.1, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_pt_lmh, Purity
// Limit High, DCTLUI_SLIDER_FLOAT, 0.25, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_pt_lmh_r, Purity Limit High R, DCTLUI_SLIDER_FLOAT, 0.5,
// 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_pt_lmh_b, Purity Limit High B,
// DCTLUI_SLIDER_FLOAT, 0.0, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_ptl_enable,
// Enable Purity Softclip, DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_ptl_c, Purity
// Softclip C, DCTLUI_SLIDER_FLOAT, 0.06, 0.0, 0.25, 0.0025)
// DEFINE_UI_PARAMS(_ptl_m, Purity Softclip M, DCTLUI_SLIDER_FLOAT, 0.08, 0.0,
// 0.25, 0.0025) DEFINE_UI_PARAMS(_ptl_y, Purity Softclip Y,
// DCTLUI_SLIDER_FLOAT, 0.06, 0.0, 0.25, 0.0025) DEFINE_UI_PARAMS(_ptm_enable,
// Enable Mid Purity, DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_ptm_low, Mid Purity
// Low, DCTLUI_SLIDER_FLOAT, 0.4, 0.0, 2.0, 0.02) DEFINE_UI_PARAMS(_ptm_low_rng,
// Mid Purity Low Range, DCTLUI_SLIDER_FLOAT, 0.25, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_ptm_low_st, Mid Purity Low Strength, DCTLUI_SLIDER_FLOAT,
// 0.5, 0.1, 1.0, 0.01) DEFINE_UI_PARAMS(_ptm_high, Mid Purity High,
// DCTLUI_SLIDER_FLOAT, -0.8, -0.9, 0.0, 0.01) DEFINE_UI_PARAMS(_ptm_high_rng,
// Mid Purity High Range, DCTLUI_SLIDER_FLOAT, 0.35, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_ptm_high_st, Mid Purity High Strength, DCTLUI_SLIDER_FLOAT,
// 0.4, 0.1, 1.0, 0.01) DEFINE_UI_PARAMS(_brl_enable, Enable Brilliance,
// DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_brl, Brilliance, DCTLUI_SLIDER_FLOAT,
// 0.0, -6.0, 2.0, 0.08) DEFINE_UI_PARAMS(_brl_r, Brilliance R,
// DCTLUI_SLIDER_FLOAT, -2.5, -6.0, 2.0, 0.08) DEFINE_UI_PARAMS(_brl_g,
// Brilliance G, DCTLUI_SLIDER_FLOAT, -1.5, -6.0, 2.0, 0.08)
// DEFINE_UI_PARAMS(_brl_b, Brilliance B, DCTLUI_SLIDER_FLOAT, -1.5, -6.0, 2.0,
// 0.08) DEFINE_UI_PARAMS(_brl_rng, Brilliance Range, DCTLUI_SLIDER_FLOAT, 0.5,
// 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_brl_st, Brilliance Strength,
// DCTLUI_SLIDER_FLOAT, 0.35, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_brlp_enable,
// Enable Post Brilliance, DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_brlp,
// Brilliance Post, DCTLUI_SLIDER_FLOAT, -0.5, -1.0, 0.0, 0.01)
// DEFINE_UI_PARAMS(_brlp_r, Post Brilliance R, DCTLUI_SLIDER_FLOAT, -1.25,
// -3.0, 0.0, 0.03) DEFINE_UI_PARAMS(_brlp_g, Post Brilliance G,
// DCTLUI_SLIDER_FLOAT, -1.25, -3.0, 0.0, 0.03) DEFINE_UI_PARAMS(_brlp_b, Post
// Brilliance B, DCTLUI_SLIDER_FLOAT, -0.25, -3.0, 0.0, 0.03)
// DEFINE_UI_PARAMS(_hc_enable, Enable Hue Contrast, DCTLUI_CHECK_BOX, 1)
// DEFINE_UI_PARAMS(_hc_r, Hue Contrast R, DCTLUI_SLIDER_FLOAT, 1.0, 0.0, 2.0,
// 0.02) DEFINE_UI_PARAMS(_hc_r_rng, Hue Contrast R Range, DCTLUI_SLIDER_FLOAT,
// 0.3, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_rgb_enable, Enable Hueshift RGB,
// DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_hs_r, Hueshift R, DCTLUI_SLIDER_FLOAT,
// 0.6, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_r_rng, Hueshift R Range,
// DCTLUI_SLIDER_FLOAT, 0.6, 0.0, 2.0, 0.02) DEFINE_UI_PARAMS(_hs_g, Hueshift G,
// DCTLUI_SLIDER_FLOAT, 0.35, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_g_rng,
// Hueshift G Range, DCTLUI_SLIDER_FLOAT, 1.0, 0.0, 2.0, 0.02)
// DEFINE_UI_PARAMS(_hs_b, Hueshift B, DCTLUI_SLIDER_FLOAT, 0.66, 0.0, 1.0,
// 0.01) DEFINE_UI_PARAMS(_hs_b_rng, Hueshift B Range, DCTLUI_SLIDER_FLOAT, 1.0,
// 0.0, 4.0, 0.02) DEFINE_UI_PARAMS(_hs_cmy_enable, Enable Hueshift CMY,
// DCTLUI_CHECK_BOX, 1) DEFINE_UI_PARAMS(_hs_c, Hueshift C, DCTLUI_SLIDER_FLOAT,
// 0.25, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_c_rng, Hueshift C Range,
// DCTLUI_SLIDER_FLOAT, 1.0, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_m, Hueshift M,
// DCTLUI_SLIDER_FLOAT, 0.0, 0.0, 1.0, 0.01) DEFINE_UI_PARAMS(_hs_m_rng,
// Hueshift M Range, DCTLUI_SLIDER_FLOAT, 1.0, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_hs_y, Hueshift Y, DCTLUI_SLIDER_FLOAT, 0.0, 0.0, 1.0, 0.01)
// DEFINE_UI_PARAMS(_hs_y_rng, Hueshift Y Range, DCTLUI_SLIDER_FLOAT, 1.0,
// 0.0, 1.0, 0.01)

// DEFINE_UI_PARAMS(_clamp, Clamp, DCTLUI_CHECK_BOX, 1)
// DEFINE_UI_PARAMS(_tn_su, Surround, DCTLUI_COMBO_BOX, 1, {_Dark, _Dim,
// _Bright}, {Dark, Dim, Bright}) DEFINE_UI_PARAMS(_display_gamut, Display
// Gamut, DCTLUI_COMBO_BOX, 0, {Rec709, P3D65, Rec2020, P3D60, P3DCI, XYZ},
// {Rec.709, P3-D65, Rec.2020 (P3 Limited), P3-D60, P3-DCI, XYZ})
// DEFINE_UI_PARAMS(_eotf, Display EOTF, DCTLUI_COMBO_BOX, 2, {eotf0, eotf1,
// eotf2, eotf3, eotf4, eotf5}, {Linear, 2.2 Power sRGB Display, 2.4 Power
// Rec.1886, 2.6 Power DCI, ST 2084 PQ, HLG})

/*------------------------------------------------------------------------------------------------------------
!!! TO ENABLE STICKSHIFT MODE FOR CUSTOM LOOK CREATION: **COMMENT OUT** all of
the preset parameters below.
-------------------------------------------------------------------------------------------------------------*/

/* Optionally Enable the Base Preset
    If you really want the Base preset, you can enable the look_preset
   definition below and disable the other one. Leaving it disabled by default as
   it is a perilous undertaking to create a nice picture using this as a
   starting point.
*/
// DEFINE_UI_PARAMS(look_preset, Look Preset, DCTLUI_COMBO_BOX, 0, {look0,
// look1, look2, look3, look4, look5, look6, look7}, {Standard, Arriba, Sylvan,
// Colorful, Aery, Dystopic, Umbra, Base})
// DEFINE_UI_PARAMS(look_preset, Look Preset, DCTLUI_COMBO_BOX, 0,
//                  { look0, look1, look2, look3, look4, look5, look6 },
//                  { Standard, Arriba, Sylvan, Colorful, Aery, Dystopic, Umbra
//                  })

// DEFINE_UI_PARAMS(tonescale_preset, Tonescale Preset, DCTLUI_COMBO_BOX, 0,
//                  { tsprst0, tsprst1, tsprst2, tsprst3, tsprst4, tsprst5,
//                    tsprst6, tsprst7, tsprst8, tsprst9, tsprst10, tsprst11,
//                    tsprst12, tsprst13 },
//                  { USE LOOK PRESET, Low Contrast, Medium Contrast,
//                    High Contrast, Arriba Tonescale, Sylvan Tonescale,
//                    Colorful Tonescale, Aery Tonescale, Dystopic Tonescale,
//                    Umbra Tonescale, ACES - 1.x, ACES - 2.0, Marvelous
//                    Tonescape, DaGrinchi ToneGroan })
// DEFINE_UI_PARAMS(_cwp, Creative White, DCTLUI_COMBO_BOX, 0,
//                  { _cwp0, _cwp1, _cwp2, _cwp3, _cwp4, _cwp5, _cwp6 },
//                  { USE LOOK PRESET, D93, D75, D65, D60, D55, D50 })
// DEFINE_UI_PARAMS(_cwp_lm, Creative White Limit, DCTLUI_SLIDER_FLOAT, 0.25,
// 0.0,
//                  1.0, 0.0)
// DEFINE_UI_PARAMS(
//     display_encoding_preset, Display Encoding Preset, DCTLUI_COMBO_BOX, 0,
//     { rec1886, srgb, displayp3, p3d60, p3dci, xyz, rec2100pq, rec2100hlg,
//       dolbypq },
//     { Rec .1886 - 2.4 Power / Rec .709, sRGB Display - 2.2 Power / Rec .709,
//       Display P3 - 2.2 Power / P3 - D65, DCI - 2.6 Power / P3 - D60,
//       DCI - 2.6 Power / P3 - DCI, DCI - 2.6 Power / XYZ,
//       Rec .2100 - PQ / Rec .2020(P3 Limited),
//       Rec .2100 - HLG / Rec .2020(P3 Limited), Dolby - PQ / P3 - D65 })

/*------------------------------------------------------------------------------------------------------------*/

/******************************************************************
  Gamut Conversion Matrices
 ******************************************************************/
// Input gamut conversion matrices

// ACES AP0 to XYZ D65 (CAT02)
const static float3x3 matrix_ap0_to_xyz =
    make_float3x3(make_float3(0.938630948750273197f, -0.00574192055037397141f,
                              0.017566898851772296f),
                  make_float3(0.338093594922021567f, 0.72721390281143572f,
                              -0.0653074977334571899f),
                  make_float3(0.000723121511341165988f,
                              0.000818441849244731985f, 1.08751618739929268f));
// ACES AP1 to XYZ D65 (CAT02)
const static float3x3 matrix_ap1_to_xyz =
    make_float3x3(make_float3(0.652418717671912951f, 0.127179925537538263f,
                              0.170857283842220459f),
                  make_float3(0.268064059194271287f, 0.672464478992617742f,
                              0.0594714618131108388f),
                  make_float3(-0.0054699285104975676f, 0.00518279997697511721f,
                              1.08934487929340107f));
const static float3x3 matrix_rec2020_to_xyz =
    make_float3x3(make_float3(0.636958048301290991f, 0.144616903586208406f,
                              0.168880975164172054f),
                  make_float3(0.26270021201126692f, 0.677998071518871148f,
                              0.0593017164698619384f),
                  make_float3(4.9999999999999999e-17f, 0.0280726930490874452f,
                              1.06098505771079066f));
const static float3x3 matrix_arriwg3_to_xyz = make_float3x3(
    make_float3(0.638007619284f, 0.214703856337f, 0.097744451431f),
    make_float3(0.291953779f, 0.823841041511f, -0.11579482051f),
    make_float3(0.002798279032f, -0.067034235689f, 1.15329370742f));
const static float3x3 matrix_arriwg4_to_xyz =
    make_float3x3(make_float3(0.704858320407231953f, 0.129760295170463003f,
                              0.115837311473976537f),
                  make_float3(0.254524176404026969f, 0.781477732712002049f,
                              -0.0360019091160290391f),
                  make_float3(0.0f, 0.0f, 1.08905775075987843f));
const static float3x3 matrix_redwg_to_xyz =
    make_float3x3(make_float3(0.735275245905858799f, 0.0686094106139610721f,
                              0.14657127053185201f),
                  make_float3(0.286694099499934962f, 0.842979134016975662f,
                              -0.129673233516910319f),
                  make_float3(-0.0796808568783676785f, -0.347343216994429771f,
                              1.51608182463267593f));
const static float3x3 matrix_sonysgamut3_to_xyz =
    make_float3x3(make_float3(0.706482713192318812f, 0.12880104979055762f,
                              0.115172164068795255f),
                  make_float3(0.270979670813492168f, 0.786606411220905466f,
                              -0.0575860820343976273f),
                  make_float3(-0.00967784538619615754f, 0.00460003749251991934f,
                              1.09413555865355483f));
const static float3x3 matrix_sonysgamut3cine_to_xyz =
    make_float3x3(make_float3(0.599083920758327171f, 0.248925516115423628f,
                              0.102446490177920776f),
                  make_float3(0.215075820115587457f, 0.88506850174372842f,
                              -0.100144321859315821f),
                  make_float3(-0.0320658495445057951f, -0.0276583906794915374f,
                              1.1487819909838759f));
const static float3x3 matrix_vgamut_to_xyz = make_float3x3(
    make_float3(0.679644469878f, 0.15221141244f, 0.118600044733f),
    make_float3(0.26068555009f, 0.77489446333f, -0.03558001342f),
    make_float3(-0.009310198218f, -0.004612467044f, 1.10298041602f));
const static float3x3 matrix_egamut_to_xyz =
    make_float3x3(make_float3(0.705396850087770755f, 0.164041328309919021f,
                              0.0810177486539819941f),
                  make_float3(0.280130724091105898f, 0.820206641549595106f,
                              -0.100337365640700782f),
                  make_float3(-0.103781511569163279f, -0.0729072570266306313f,
                              1.26574651935567273f));
const static float3x3 matrix_egamut2_to_xyz =
    make_float3x3(make_float3(0.736477700183697404f, 0.130739651086660136f,
                              0.0832385757813140781f),
                  make_float3(0.275069984405959256f, 0.828017790215514138f,
                              -0.103087774621473588f),
                  make_float3(-0.124225154247852534f, -0.0871597673911067433f,
                              1.30044267239883782f));
const static float3x3 matrix_davinciwg_to_xyz =
    make_float3x3(make_float3(0.700622392093671609f, 0.148774815123196763f,
                              0.101058719834803246f),
                  make_float3(0.274118510906649016f, 0.873631895940436665f,
                              -0.147750406847085763f),
                  make_float3(-0.0989629128832311411f, -0.137895325075543307f,
                              1.32591598871865268f));

// P3D65 to XYZ D65
const static float3x3 matrix_p3d65_to_xyz =
    make_float3x3(make_float3(0.486570948648216151f, 0.265667693169093f,
                              0.198217285234362467f),
                  make_float3(0.228974564069748754f, 0.691738521836506193f,
                              0.079286914093744984f),
                  make_float3(-4.00000000000000029e-17f, 0.0451133818589026167f,
                              1.04394436890097575f));
// XYZ D65 to P3D65
const static float3x3 matrix_xyz_to_p3d65 =
    make_float3x3(make_float3(2.49349691194142542f, -0.93138361791912383f,
                              -0.402710784450716841f),
                  make_float3(-0.829488969561574696f, 1.76266406031834655f,
                              0.0236246858419435941f),
                  make_float3(0.0358458302437844531f, -0.0761723892680418041f,
                              0.956884524007687309f));
// Rec709 to XYZ D65
const static float3x3 matrix_rec709_to_xyz =
    make_float3x3(make_float3(0.412390799265959229f, 0.357584339383878125f,
                              0.180480788401834347f),
                  make_float3(0.212639005871510217f, 0.71516867876775625f,
                              0.0721923153607337414f),
                  make_float3(0.0193308187155918181f, 0.119194779794626018f,
                              0.950532152249661033f));
// XYZ D65 to Rec709
const static float3x3 matrix_xyz_to_rec709 =
    make_float3x3(make_float3(3.24096994190452348f, -1.53738317757009435f,
                              -0.498610760293003552f),
                  make_float3(-0.969243636280879506f, 1.87596750150771996f,
                              0.0415550574071755843f),
                  make_float3(0.0556300796969936354f, -0.20397695888897649f,
                              1.05697151424287816f));
// P3D65 to Rec2020
const static float3x3 matrix_p3_to_rec2020 =
    make_float3x3(make_float3(0.753833034361722221f, 0.198597369052616435f,
                              0.0475695965856618441f),
                  make_float3(0.0457438489653582137f, 0.9417772198116936f,
                              0.0124789312229481135f),
                  make_float3(-0.0012103403545183941f, 0.0176017173010899926f,
                              0.983608623053428777f));
// P3DCI to XYZ DCI (NPM Matrix)
const static float3x3 matrix_p3dci_to_xyz =
    make_float3x3(make_float3(0.445169815564552429f, 0.27713440920677751f,
                              0.172282669815564504f),
                  make_float3(0.209491677912730545f, 0.721595254161043309f,
                              0.0689130679262257989f),
                  make_float3(-3.59999999999999995e-17f, 0.0470605600539811264f,
                              0.9073553943619731f));

/******************************************************************
  CAT02 Chromatic Adaptation Matrices
 ******************************************************************/

// DCI to D93 : [0.314, 0.351] to [0.283, 0.297]
const static float3x3 matrix_cat_dci_to_d93 =
    make_float3x3(make_float3(0.965685009956359863f, 0.00183745240792632103f,
                              0.0912967324256896973f),
                  make_float3(0.000514572137035429044f, 0.965166747570037842f,
                              0.036014653742313385f),
                  make_float3(0.00154250487685203596f, 0.00702651776373386383f,
                              1.47287476062774658f));
// DCI to D75 : [0.314, 0.351] to [0.29903, 0.31488]
const static float3x3 matrix_cat_dci_to_d75 =
    make_float3x3(make_float3(0.990120768547058105f, 0.0151389474049210548f,
                              0.0511047691106796265f),
                  make_float3(0.0102197211235761642f, 0.971718132495880127f,
                              0.0200536623597145081f),
                  make_float3(0.000743072712793946049f, 0.0042176349088549614f,
                              1.27959656715393066f));
// DCI to D65 : [0.314, 0.351] to [0.3127, 0.329]
const static float3x3 matrix_cat_dci_to_d65 =
    make_float3x3(make_float3(1.00951600074768066f, 0.0269675441086292267f,
                              0.0213620811700820923f),
                  make_float3(0.0187991037964820862f, 0.975330352783203125f,
                              0.0082273334264755249f),
                  make_float3(0.000134543282911180989f, 0.00217903498560190201f,
                              1.138663649559021f));
// DCI to D60 : [0.314, 0.351] to [0.32162624, 0.337737]
const static float3x3 matrix_cat_dci_to_d60 =
    make_float3x3(make_float3(1.02159523963928223f, 0.034848678857088089f,
                              0.00371252000331878705f),
                  make_float3(0.0244968775659799576f, 0.976937234401702881f,
                              0.00120301544666290305f),
                  make_float3(-0.00023391586728393999f,
                              0.000986687839031219049f, 1.05594265460968018f));
// DCI to D55 : [0.314, 0.351] to [0.33243, 0.34744]
const static float3x3 matrix_cat_dci_to_d55 = make_float3x3(
    make_float3(1.03594577312469482f, 0.0450937561690807343f,
                -0.0157573819160461426f),
    make_float3(0.0318740680813789368f, 0.977744519710540771f,
                -0.00655744969844818115f),
    make_float3(-0.000653609400615095984f, -0.000297372229397297014f,
                0.966327786445617676f));
// DCI to D50 : [0.314, 0.351] to [0.3457, 0.3585]
const static float3x3 matrix_cat_dci_to_d50 =
    make_float3x3(make_float3(1.05306875705718994f, 0.0581297315657138824f,
                              -0.0376100838184356689f),
                  make_float3(0.0412359423935413361f, 0.977693676948547363f,
                              -0.0152792222797870636f),
                  make_float3(-0.00113777676597237609f,
                              -0.00170759297907352404f, 0.867368340492248535f));

// D65 to D93 : [0.3127, 0.329] to [0.283, 0.297]
const static float3x3 matrix_cat_d65_to_d93 =
    make_float3x3(make_float3(0.95703423023223877f, -0.0247171502560377121f,
                              0.0624028593301773071f),
                  make_float3(-0.0179296955466270447f, 0.990019857883453369f,
                              0.0248119533061981201f),
                  make_float3(0.00127589143812656403f, 0.00427919067442417058f,
                              1.29345715045928955f));
// D65 to D75 : [0.3127, 0.329] to [0.29903, 0.31488]
const static float3x3 matrix_cat_d65_to_d75 =
    make_float3x3(make_float3(0.981001079082489014f, -0.0116619253531098366f,
                              0.0265614092350006104f),
                  make_float3(-0.00843488052487373352f, 0.996506094932556152f,
                              0.0105696544051170349f),
                  make_float3(0.000552809564396739006f, 0.00179840810596942902f,
                              1.12374722957611084f));
// D65 to D60 : [0.3127, 0.329] to [0.32162624, 0.337737]
const static float3x3 matrix_cat_d65_to_d60 =
    make_float3x3(make_float3(1.01182246208190918f, 0.00778879318386316299f,
                              -0.0157783031463623047f),
                  make_float3(0.00561682833358645439f, 1.00150644779205322f,
                              -0.00628517568111419678f),
                  make_float3(-0.000335735734552145004f,
                              -0.0010509500280022619f, 0.927366673946380615f));
// D65 to D55 : [0.3127, 0.329] to [0.33243, 0.34744]
const static float3x3 matrix_cat_d65_to_d55 =
    make_float3x3(make_float3(1.02585089206695557f, 0.0179439820349216461f,
                              -0.0332137793302536011f),
                  make_float3(0.0129133854061365128f, 1.00214779376983643f,
                              -0.0132421031594276428f),
                  make_float3(-0.000719940289855003032f,
                              -0.00218106806278228803f, 0.84868013858795166f));
// D65 to D50 : [0.3127, 0.329] to [0.3457, 0.3585]
const static float3x3 matrix_cat_d65_to_d50 =
    make_float3x3(make_float3(1.04257404804229736f, 0.03089117631316185f,
                              -0.052812620997428894f),
                  make_float3(0.0221935361623764038f, 1.00185668468475342f,
                              -0.0210737623274326324f),
                  make_float3(-0.00116488314233720303f,
                              -0.00342052709311246915f, 0.761789083480834961f));
// D65 to DCI-P3 : [0.3127, 0.329] to [0.314, 0.351]
const static float3x3 matrix_cat_d65_to_dci =
    make_float3x3(make_float3(0.991085588932037354f, -0.0273622870445251465f,
                              -0.0183956623077392578f),
                  make_float3(-0.0191021915525197983f, 1.02583777904510498f,
                              -0.00705372542142868042f),
                  make_float3(-8.05503223091359977e-05f,
                              -0.00195988826453685804f, 0.878238439559936523f));

// D60 to D93 : [0.32162624, 0.337737] to [0.283, 0.297]
const static float3x3 matrix_cat_d60_to_d93 =
    make_float3x3(make_float3(0.946056902408599854f, -0.0319503024220466614f,
                              0.0831701457500457764f),
                  make_float3(-0.0231979694217443466f, 0.988745808601379395f,
                              0.0330617502331733704f),
                  make_float3(0.00169203430414199807f, 0.00572328735142946243f,
                              1.39483106136322021f));
// D60 to D75 : [0.32162624, 0.337737] to [0.29903, 0.31488]
const static float3x3 matrix_cat_d60_to_d75 =
    make_float3x3(make_float3(0.969659984111785889f, -0.019138311967253685f,
                              0.0450099557638168335f),
                  make_float3(-0.0138545772060751915f, 0.995133817195892334f,
                              0.0179062262177467346f),
                  make_float3(0.000931452261283994046f, 0.00306008197367191315f,
                              1.21179807186126709f));
// D60 to D65 : [0.32162624, 0.337737] to [0.3127, 0.329]
const static float3x3 matrix_cat_d60_to_d65 =
    make_float3x3(make_float3(0.988363921642303467f, -0.00766910053789615631f,
                              0.0167641639709472656f),
                  make_float3(-0.0055409618653357029f, 0.998546123504638672f,
                              0.00667332112789154139f),
                  make_float3(0.000351537019014359008f, 0.00112883746623992898f,
                              1.07833576202392578f));
// D60 to D55 : [0.32162624, 0.337737] to [0.33243, 0.34744]
const static float3x3 matrix_cat_d60_to_d55 =
    make_float3x3(make_float3(1.01380288600921631f, 0.0100131509825587273f,
                              -0.018498346209526062f),
                  make_float3(0.00720565160736441612f, 1.00057685375213623f,
                              -0.00737529993057250977f),
                  make_float3(-0.000401133671402930997f,
                              -0.00121434964239597299f, 0.915135681629180908f));
// D60 to D50 : [0.32162624, 0.337737] to [0.3457, 0.3585]
const static float3x3 matrix_cat_d60_to_d50 =
    make_float3x3(make_float3(1.03025269508361816f, 0.0227910466492176056f,
                              -0.0392656922340393066f),
                  make_float3(0.0163766480982303619f, 1.00020599365234375f,
                              -0.0156668238341808319f),
                  make_float3(-0.000864576781168579947f,
                              -0.00254668481647968292f, 0.821422040462493896f));

// ******************************************************************

/* Math helper functions ----------------------------*/

const static float SQRT3 = 1.73205080756887729353f;
const static float PI = 3.14159265358979323846;

// Return identity 3x3 matrix
float3x3 identity() {
  return make_float3x3(make_float3(1.0f, 0.0f, 0.0f),
                       make_float3(0.0f, 1.0f, 0.0f),
                       make_float3(0.0f, 0.0f, 1.0f));
}

// Safe division of float a by float b
float sdivf(float a, float b) {
  if (b == 0.0f)
    return 0.0f;
  else
    return a / b;
}

// Safe division of float3 a by float b
float3 sdivf3f(float3 a, float b) {
  return make_float3(sdivf(a.x, b), sdivf(a.y, b), sdivf(a.z, b));
}

// Safe element-wise division of float3 a by float3 b
float3 sdivf3f3(float3 a, float3 b) {
  return make_float3(sdivf(a.x, b.x), sdivf(a.y, b.y), sdivf(a.z, b.z));
}

// Safe power function raising float a to power float b
float spowf(float a, float b) {
  if (a <= 0.0f)
    return a;
  else
    return _powf(a, b);
}

// Safe power function raising float3 a to power float b
float3 spowf3(float3 a, float b) {
  return make_float3(spowf(a.x, b), spowf(a.y, b), spowf(a.z, b));
}
// Return the hypot or vector length of float2 v
float hypotf2(float2 v) { return _sqrtf(_fmaxf(0.0f, v.x * v.x + v.y * v.y)); }

// Return the hypot or vector length of float3 v
float hypotf3(float3 v) {
  return _sqrtf(_fmaxf(0.0f, v.x * v.x + v.y * v.y + v.z * v.z));
}

// Return the min of float3 a
float fmaxf3(float3 a) { return _fmaxf(a.x, _fmaxf(a.y, a.z)); }

// Return the max of float3 a
float fminf3(float3 a) { return _fminf(a.x, _fminf(a.y, a.z)); }

// Clamp float3 a to max value mx
float3 clampmaxf3(float3 a, float mx) {
  return make_float3(_fminf(a.x, mx), _fminf(a.y, mx), _fminf(a.z, mx));
}

// Clamp float3 a to min value mn
float3 clampminf3(float3 a, float mn) {
  return make_float3(_fmaxf(a.x, mn), _fmaxf(a.y, mn), _fmaxf(a.z, mn));
}

// Clamp float3 a to min value mn and max value mx
float clampf(float a, float mn, float mx) { return _fminf(_fmaxf(a, mn), mx); }
float3 clampf3(float3 a, float mn, float mx) {
  return make_float3(clampf(a.x, mn, mx), clampf(a.y, mn, mx),
                     clampf(a.z, mn, mx));
}

/* OETF Linearization Transfer Functions
 * ---------------------------------------- */

float oetf_davinci_intermediate(float x) {
  return x <= 0.02740668f ? x / 10.44426855f
                          : _exp2f(x / 0.07329248f - 7.0f) - 0.0075f;
}
float oetf_filmlight_tlog(float x) {
  return x < 0.075f ? (x - 0.075f) / 16.184376489665897f
                    : _expf((x - 0.5520126568606655f) / 0.09232902596577353f) -
                          0.0057048244042473785f;
}
float oetf_acescct(float x) {
  return x <= 0.155251141552511f ? (x - 0.0729055341958355f) / 10.5402377416545f
                                 : _exp2f(x * 17.52f - 9.72f);
}
float oetf_arri_logc3(float x) {
  return x < 5.367655f * 0.010591f + 0.092809f
             ? (x - 0.092809f) / 5.367655f
             : (_exp10f((x - 0.385537f) / 0.247190f) - 0.052272f) / 5.555556f;
}
float oetf_arri_logc4(float x) {
  return x < -0.7774983977293537f
             ? x * 0.3033266726886969f - 0.7774983977293537f
             : (_exp2f(14.0f * (x - 0.09286412512218964f) /
                           0.9071358748778103f +
                       6.0f) -
                64.0f) /
                   2231.8263090676883f;
}
float oetf_red_log3g10(float x) {
  return x < 0.0f ? (x / 15.1927f) - 0.01f
                  : (_exp10f(x / 0.224282f) - 1.0f) / 155.975327f - 0.01f;
}
float oetf_panasonic_vlog(float x) {
  return x < 0.181f ? (x - 0.125f) / 5.6f
                    : _exp10f((x - 0.598206f) / 0.241514f) - 0.00873f;
}
float oetf_sony_slog3(float x) {
  return x < 171.2102946929f / 1023.0f
             ? (x * 1023.0f - 95.0f) * 0.01125f / (171.2102946929f - 95.0f)
             : (_exp10f(((x * 1023.0f - 420.0f) / 261.5f)) * (0.18f + 0.01f) -
                0.01f);
}
float oetf_fujifilm_flog2(float x) {
  return x < 0.100686685370811f
             ? (x - 0.092864f) / 8.799461f
             : (_exp10f(((x - 0.384316f) / 0.245281f)) / 5.555556f -
                0.064829f / 5.555556f);
}

float3 linearize(float3 rgb, int tf) {
  if (tf == 0) { // Linear
    return rgb;
  } else if (tf == 1) { // Davinci Intermediate
    rgb.x = oetf_davinci_intermediate(rgb.x);
    rgb.y = oetf_davinci_intermediate(rgb.y);
    rgb.z = oetf_davinci_intermediate(rgb.z);
  } else if (tf == 2) { // Filmlight T-Log
    rgb.x = oetf_filmlight_tlog(rgb.x);
    rgb.y = oetf_filmlight_tlog(rgb.y);
    rgb.z = oetf_filmlight_tlog(rgb.z);
  } else if (tf == 3) { // ACEScct
    rgb.x = oetf_acescct(rgb.x);
    rgb.y = oetf_acescct(rgb.y);
    rgb.z = oetf_acescct(rgb.z);
  } else if (tf == 4) { // Arri LogC3
    rgb.x = oetf_arri_logc3(rgb.x);
    rgb.y = oetf_arri_logc3(rgb.y);
    rgb.z = oetf_arri_logc3(rgb.z);
  } else if (tf == 5) { // Arri LogC4
    rgb.x = oetf_arri_logc4(rgb.x);
    rgb.y = oetf_arri_logc4(rgb.y);
    rgb.z = oetf_arri_logc4(rgb.z);
  } else if (tf == 6) { // RedLog3G10
    rgb.x = oetf_red_log3g10(rgb.x);
    rgb.y = oetf_red_log3g10(rgb.y);
    rgb.z = oetf_red_log3g10(rgb.z);
  } else if (tf == 7) { // Panasonic V-Log
    rgb.x = oetf_panasonic_vlog(rgb.x);
    rgb.y = oetf_panasonic_vlog(rgb.y);
    rgb.z = oetf_panasonic_vlog(rgb.z);
  } else if (tf == 8) { // Sony S-Log3
    rgb.x = oetf_sony_slog3(rgb.x);
    rgb.y = oetf_sony_slog3(rgb.y);
    rgb.z = oetf_sony_slog3(rgb.z);
  } else if (tf == 9) { // Fuji F-Log2
    rgb.x = oetf_fujifilm_flog2(rgb.x);
    rgb.y = oetf_fujifilm_flog2(rgb.y);
    rgb.z = oetf_fujifilm_flog2(rgb.z);
  }
  return rgb;
}

/* EOTF Transfer Functions ---------------------------------------- */

float3 eotf_hlg(float3 rgb, int inverse) {
  /* Apply the HLG Forward or Inverse EOTF for 1000 nits.
      ITU-R Rec BT.2100-2 https://www.itu.int/rec/R-REC-BT.2100
      ITU-R Rep BT.2390-8: https://www.itu.int/pub/R-REP-BT.2390
  */

  if (inverse == 1) {
    float Yd = 0.2627f * rgb.x + 0.6780f * rgb.y + 0.0593f * rgb.z;
    rgb = rgb * spowf(Yd, (1.0f - 1.2f) / 1.2f);
    rgb.x =
        rgb.x <= 1.0f / 12.0f
            ? _sqrtf(3.0f * rgb.x)
            : 0.17883277f * _logf(12.0f * rgb.x - 0.28466892f) + 0.55991073f;
    rgb.y =
        rgb.y <= 1.0f / 12.0f
            ? _sqrtf(3.0f * rgb.y)
            : 0.17883277f * _logf(12.0f * rgb.y - 0.28466892f) + 0.55991073f;
    rgb.z =
        rgb.z <= 1.0f / 12.0f
            ? _sqrtf(3.0f * rgb.z)
            : 0.17883277f * _logf(12.0f * rgb.z - 0.28466892f) + 0.55991073f;
  } else {
    rgb.x = rgb.x <= 0.5f
                ? rgb.x * rgb.x / 3.0f
                : (_expf((rgb.x - 0.55991073f) / 0.17883277f) + 0.28466892f) /
                      12.0f;
    rgb.y = rgb.y <= 0.5f
                ? rgb.y * rgb.y / 3.0f
                : (_expf((rgb.y - 0.55991073f) / 0.17883277f) + 0.28466892f) /
                      12.0f;
    rgb.z = rgb.z <= 0.5f
                ? rgb.z * rgb.z / 3.0f
                : (_expf((rgb.z - 0.55991073f) / 0.17883277f) + 0.28466892f) /
                      12.0f;
    float Ys = 0.2627f * rgb.x + 0.6780f * rgb.y + 0.0593f * rgb.z;
    rgb = rgb * spowf(Ys, 1.2f - 1.0f);
  }
  return rgb;
}

float3 eotf_pq(float3 rgb, int inverse) {
  /* Apply the ST-2084 PQ Forward or Inverse EOTF
      ITU-R Rec BT.2100-2 https://www.itu.int/rec/R-REC-BT.2100
      ITU-R Rep BT.2390-9 https://www.itu.int/pub/R-REP-BT.2390
      Note: in the spec there is a normalization for peak display luminance.
      For this function we assume the input is already normalized such that 1.0
     = 10,000 nits
  */

  const float m1 = 2610.0f / 16384.0f;
  const float m2 = 2523.0f / 32.0f;
  const float c1 = 107.0f / 128.0f;
  const float c2 = 2413.0f / 128.0f;
  const float c3 = 2392.0f / 128.0f;

  if (inverse == 1) {
    rgb = spowf3(rgb, m1);
    rgb = spowf3((c1 + c2 * rgb) / (1.0f + c3 * rgb), m2);
  } else {
    rgb = spowf3(rgb, 1.0f / m2);
    rgb = spowf3((rgb - c1) / (c2 - c3 * rgb), 1.0f / m1);
  }
  return rgb;
}

/* Functions for OpenDRT ---------------------------------------- */

float compress_hyperbolic_power(float x, float s, float p) {
  // Simple hyperbolic compression function
  // https://www.desmos.com/calculator/ofwtcmzc3w
  return spowf(x / (x + s), p);
}

float compress_toe_quadratic(float x, float toe, int inv) {
  // Quadratic toe compress function
  // https://www.desmos.com/calculator/skk8ahmnws
  if (toe == 0.0f)
    return x;
  if (inv == 0) {
    return spowf(x, 2.0f) / (x + toe);
  } else {
    return (x + _sqrtf(x * (4.0f * toe + x))) / 2.0f;
  }
}

float compress_toe_cubic(float x, float m, float w, int inv) {
  // https://www.desmos.com/calculator/ubgteikoke
  if (m == 1.0f)
    return x;
  float x2 = x * x;
  if (inv == 0) {
    return x * (x2 + m * w) / (x2 + w);
  } else {
    float p0 = x2 - 3.0f * m * w;
    float p1 = 2.0f * x2 + 27.0f * w - 9.0f * m * w;
    float p2 =
        _powf(_sqrtf(x2 * p1 * p1 - 4 * p0 * p0 * p0) / 2.0f + x * p1 / 2.0f,
              1.0f / 3.0f);
    return p0 / (3.0f * p2) + p2 / 3.0f + x / 3.0f;
  }
}

float complement_power(float x, float p) {
  return 1.0f - spowf(1.0f - x, 1.0f / p);
}

float sigmoid_cubic(float x, float s) {
  // Simple cubic sigmoid: https://www.desmos.com/calculator/hzgib42en6
  if (x < 0.0f || x > 1.0f)
    return 1.0f;
  return 1.0f + s * (1.0f - 3.0f * x * x + 2.0f * x * x * x);
}

float contrast_high(float x, float p, float pv, float pv_lx, int inv) {
  // High exposure adjustment with linear extension
  // https://www.desmos.com/calculator/etjgwyrgad
  const float x0 = 0.18f * _powf(2.0f, pv);
  if (x < x0 || p == 1.0f)
    return x;

  const float o = x0 - x0 / p;
  const float s0 = _powf(x0, 1.0f - p) / p;
  const float x1 = x0 * _powf(2.0f, pv_lx);
  const float k1 = p * s0 * _powf(x1, p) / x1;
  const float y1 = s0 * _powf(x1, p) + o;
  if (inv == 1)
    return x > y1 ? (x - y1) / k1 + x1 : _powf((x - o) / s0, 1.0f / p);
  else
    return x > x1 ? k1 * (x - x1) + y1 : s0 * _powf(x, p) + o;
}

float softplus_constraint(float x, float s, float x0, float y0) {
  // Softplus with (x0, y0) intersection constraint
  // https://www.desmos.com/calculator/doipi4u0ce
  if (x > 10.0f * s + y0 || s < 1e-3f)
    return x;
  float m = 1.0f;
  if (_fabs(y0) > 1e-6f)
    m = _expf(y0 / s);
  m -= _expf(x0 / s);
  return s * _logf(_fmaxf(0.0f, m + _expf(x / s)));
}

float softplus(float x, float s) {
  // Softplus unconstrained
  // https://www.desmos.com/calculator/mr9rmujsmn
  if (x > 10.0f * s || s < 1e-4f)
    return x;
  return s * _logf(_fmaxf(0.0f, 1.0f + _expf(x / s)));
}

float gauss_window(float x, float w) {
  // Simple gaussian window https://www.desmos.com/calculator/vhr9hstlyk
  return _expf(-x * x / w);
}

float2 opponent(float3 rgb) {
  // Simple Cyan-Yellow / Green-Magenta opponent space for calculating smooth
  // achromatic distance and hue angles
  return make_float2(rgb.x - rgb.z, rgb.y - (rgb.x + rgb.z) / 2.0f);
}

float hue_offset(float h, float o) {
  // Offset hue maintaining 0-2*pi range with modulo
  return _fmod(h - o + PI, 2.0 * PI) - PI;
}

float3 display_gamut_whitepoint(float3 rgb, float tsn, float cwp_lm,
                                int display_gamut, int cwp) {
  // Do final display gamut and creative whitepoint conversion.
  // Must be done twice for the tonescale overlay, thus a separate function.

  // First, convert from P3D65 to XYZ D65
  rgb = vdot(matrix_p3d65_to_xyz, rgb);

  // Store "neutral" axis for mixing with Creative White Range control
  float3 cwp_neutral = rgb;

  float cwp_f = _powf(tsn, 2.0f * cwp_lm);

  if (display_gamut < 3) { // D65 aligned P3 or Rec.709 display gamuts
    if (cwp == 0)
      rgb = vdot(matrix_cat_d65_to_d93, rgb); // D93
    else if (cwp == 1)
      rgb = vdot(matrix_cat_d65_to_d75, rgb); // D75
    // else if (cwp==2) rgb = vdot(matrix_cat_d65_to_d60, rgb); // D65
    else if (cwp == 3)
      rgb = vdot(matrix_cat_d65_to_d60, rgb); // D60
    else if (cwp == 4)
      rgb = vdot(matrix_cat_d65_to_d55, rgb); // D55
    else if (cwp == 5)
      rgb = vdot(matrix_cat_d65_to_d50, rgb); // D50
  } else if (display_gamut == 3) {            // P3-D60
    if (cwp == 0)
      rgb = vdot(matrix_cat_d60_to_d93, rgb); // D93
    else if (cwp == 1)
      rgb = vdot(matrix_cat_d60_to_d75, rgb); // D75
    else if (cwp == 2)
      rgb = vdot(matrix_cat_d60_to_d65, rgb); // D65
    // D60
    else if (cwp == 4)
      rgb = vdot(matrix_cat_d60_to_d55, rgb); // D55
    else if (cwp == 5)
      rgb = vdot(matrix_cat_d60_to_d50, rgb); // D50
  } else {                                    // DCI P3 or DCI X'Y'Z'
    // Keep "Neutral" axis as D65, don't want green midtones in P3-DCI
    // container.
    cwp_neutral = vdot(matrix_cat_dci_to_d65, rgb);
    if (cwp == 0)
      rgb = vdot(matrix_cat_dci_to_d93, rgb); // D93
    else if (cwp == 1)
      rgb = vdot(matrix_cat_dci_to_d75, rgb); // D75
    else if (cwp == 2)
      rgb = cwp_neutral;
    else if (cwp == 3)
      rgb = vdot(matrix_cat_dci_to_d60, rgb); // D60
    else if (cwp == 4)
      rgb = vdot(matrix_cat_dci_to_d55, rgb); // D55
    else if (cwp == 5)
      rgb = vdot(matrix_cat_dci_to_d50, rgb); // D50
  }

  // Mix between Creative Whitepoint and "neutral" axis with Creative White
  // Range control.
  rgb = rgb * cwp_f + cwp_neutral * (1.0f - cwp_f);

  // RGB is now aligned to the selected creative white
  // and we can convert back to the final target display gamut
  if (display_gamut == 0) { // Rec.709
    rgb = vdot(matrix_xyz_to_rec709, rgb);
  } else if (display_gamut == 5) { // DCDM X'Y'Z'
    // Convert whitepoint from D65 to DCI
    rgb = vdot(matrix_cat_d65_to_dci, rgb);
  } else { // For all others, convert to P3D65
    rgb = vdot(matrix_xyz_to_p3d65, rgb);
  }

  // Post creative whitepoint normalization so that peak luminance does not
  // exceed display maximum. We could calculate this by storing a 1,1,1 value in
  // p3d65 and then normalize by the result through the cat and xyz to rgb
  // matrix. Instead we use pre-calculated constants to avoid the extra
  // calculations.

  /* Pre-calculated normalization factors are inline below
   */

  float cwp_norm = 1.0f;
  /* Display Gamut - Rec.709
    rec709 d93: 0.744192699063f
    rec709 d75: 0.873470832146f
    rec709 d60: 0.955936992163f
    rec709 d55: 0.905671332781f
    rec709 d50: 0.850004385027f
  */
  if (display_gamut == 0) { // Rec.709
    if (cwp == 0)
      cwp_norm = 0.744192699063f; // D93
    else if (cwp == 1)
      cwp_norm = 0.873470832146f; // D75
    // else if (cwp == 2) cwp_norm = 1.0f; // D65
    else if (cwp == 3)
      cwp_norm = 0.955936992163f; // D60
    else if (cwp == 4)
      cwp_norm = 0.905671332781f; // D55
    else if (cwp == 5)
      cwp_norm = 0.850004385027f; // D50
  }
  /* Display Gamut - P3D65
    p3d65 d93: 0.762687057298f
    p3d65 d75: 0.884054083328f
    p3d65 d60: 0.964320186739f
    p3d65 d55: 0.923076518860f
    p3d65 d50: 0.876572837784f
  */
  else if (display_gamut == 1 ||
           display_gamut == 2) { // P3D65 or P3 Limited Rec.2020
    if (cwp == 0)
      cwp_norm = 0.762687057298f; // D93
    else if (cwp == 1)
      cwp_norm = 0.884054083328f; // D75
    // else if (cwp == 2) cwp_norm = 1.0f; // D65
    else if (cwp == 3)
      cwp_norm = 0.964320186739f; // D60
    else if (cwp == 4)
      cwp_norm = 0.923076518860f; // D55
    else if (cwp == 5)
      cwp_norm = 0.876572837784f; // D50
  }
  /* Display Gamut - P3D60
    p3d60 d93: 0.704956321013f
    p3d60 d75: 0.816715709816f
    p3d60 d65: 0.923382193663f
    p3d60 d55: 0.956138500287f
    p3d60 d50: 0.906801453023f
  */
  else if (display_gamut == 3) { // P3D60
    if (cwp == 0)
      cwp_norm = 0.704956321013f; // D93
    else if (cwp == 1)
      cwp_norm = 0.816715709816f; // D75
    else if (cwp == 2)
      cwp_norm = 0.923382193663f; // D65
    // else if (cwp == 3) cwp_norm = 1.0f; // D60
    else if (cwp == 4)
      cwp_norm = 0.956138500287f; // D55
    else if (cwp == 5)
      cwp_norm = 0.906801453023f; // D50
  }
  /* Display Gamut - P3-DCI
    p3dci d93: 0.665336141225f
    p3dci d75: 0.770397131382f
    p3dci d65: 0.870572343302f
    p3dci d60: 0.891354547503f
    p3dci d55: 0.855327825187f
    p3dci d50: 0.814566436117f
*/
  else if (display_gamut == 4) { // P3DCI
    if (cwp == 0)
      cwp_norm = 0.665336141225f; // D93
    else if (cwp == 1)
      cwp_norm = 0.770397131382f; // D75
    else if (cwp == 2)
      cwp_norm = 0.870572343302f; // D65
    else if (cwp == 3)
      cwp_norm = 0.891354547503f; // D60
    else if (cwp == 4)
      cwp_norm = 0.855327825187f; // D55
    else if (cwp == 5)
      cwp_norm = 0.814566436117f; // D50
  }
  /* Display Gamut - DCDM XYZ
    p3dci d93: 0.707142784007f
    p3dci d75: 0.815561082617f
    */
  else if (display_gamut == 5) { // DCDM X'Y'Z'
    if (cwp == 0)
      cwp_norm = 0.707142784007f; // D93
    else if (cwp == 1)
      cwp_norm = 0.815561082617f; // D75
    else if (cwp >= 2)
      cwp_norm = 0.916555279740f; // 48/52.37 for D65 and warmer (see DCI spec)
  }

  // only normalize values affected by range control
  rgb *= cwp_norm * cwp_f + 1.0f - cwp_f;

  return rgb;
}

float3 opendrt_transform(float3 rgb, OpenDrtUniforms uniforms) {

  /*****************************************************
    Parameter Setup
    --------------------------------------------------*/
  // Unpack uniforms from struct
  uint in_gamut = uniforms.inGamut; // Input Gamut
  uint in_oetf = uniforms.inOetf;   // Input OETF
  uint display_encoding_preset =
      uniforms.displayEncodingPreset;          // Display Encoding Preset
  uint look_preset = uniforms.lookPreset;      // Look Preset
  float tn_Lp = uniforms.displayPeakLuminance; // Display Peak Luminance

  // Init look preset variables
  int tn_hcon_enable, tn_lcon_enable, pt_enable, ptl_enable, ptm_enable,
      brl_enable, brlp_enable, hc_enable, hs_rgb_enable, hs_cmy_enable, cwp,
      tn_su, clamp, display_gamut, eotf;

  float tn_con, tn_sh, tn_toe, tn_off, tn_hcon, tn_hcon_pv, tn_hcon_st, tn_lcon,
      tn_lcon_w, cwp_lm, rs_sa, rs_rw, rs_bw, pt_lml, pt_lml_r, pt_lml_g,
      pt_lml_b, pt_lmh, pt_lmh_r, pt_lmh_b, ptl_c, ptl_m, ptl_y, ptm_low,
      ptm_low_rng, ptm_low_st, ptm_high, ptm_high_rng, ptm_high_st, brl, brl_r,
      brl_g, brl_b, brl_rng, brl_st, brlp, brlp_r, brlp_g, brlp_b, hc_r,
      hc_r_rng, hs_r, hs_r_rng, hs_g, hs_g_rng, hs_b, hs_b_rng, hs_c, hs_c_rng,
      hs_m, hs_m_rng, hs_y, hs_y_rng;

  /*----------- LOOK PRESETS -----------------*/
  if (look_preset == 0) { // Standard
    tn_con = 1.66f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.005f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 0;
    tn_lcon = 0.0f;
    tn_lcon_w = 0.5f;
    cwp = 2;
    cwp_lm = 0.25f;
    rs_sa = 0.35f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.25f;
    pt_lml_r = 0.5f;
    pt_lml_g = 0.0f;
    pt_lml_b = 0.1f;
    pt_lmh = 0.25f;
    pt_lmh_r = 0.5f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.06f;
    ptl_m = 0.08f;
    ptl_y = 0.06f;
    ptm_enable = 1;
    ptm_low = 0.4f;
    ptm_low_rng = 0.25f;
    ptm_low_st = 0.5f;
    ptm_high = -0.8f;
    ptm_high_rng = 0.35f;
    ptm_high_st = 0.4f;
    brl_enable = 1;
    brl = 0.0f;
    brl_r = -2.5f;
    brl_g = -1.5f;
    brl_b = -1.5f;
    brl_rng = 0.5f;
    brl_st = 0.35f;
    brlp_enable = 1;
    brlp = -0.5f;
    brlp_r = -1.25f;
    brlp_g = -1.25f;
    brlp_b = -0.25f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.3f;
    hs_rgb_enable = 1;
    hs_r = 0.6f;
    hs_r_rng = 0.6f;
    hs_g = 0.35f;
    hs_g_rng = 1.0f;
    hs_b = 0.66f;
    hs_b_rng = 1.0f;
    hs_cmy_enable = 1;
    hs_c = 0.25f;
    hs_c_rng = 1.0f;
    hs_m = 0.0f;
    hs_m_rng = 1.0f;
    hs_y = 0.0f;
    hs_y_rng = 1.0f;
  } else if (look_preset == 1) { // Arriba
    tn_con = 1.05f;
    tn_sh = 0.5f;
    tn_toe = 0.1f;
    tn_off = 0.01f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.5f;
    tn_lcon_w = 0.2f;
    cwp = 2;
    cwp_lm = 0.25f;
    rs_sa = 0.35f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.25f;
    pt_lml_r = 0.45f;
    pt_lml_g = 0.0f;
    pt_lml_b = 0.1f;
    pt_lmh = 0.25f;
    pt_lmh_r = 0.25f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.06f;
    ptl_m = 0.08f;
    ptl_y = 0.06f;
    ptm_enable = 1;
    ptm_low = 1.0f;
    ptm_low_rng = 0.4f;
    ptm_low_st = 0.5f;
    ptm_high = -0.8f;
    ptm_high_rng = 0.66f;
    ptm_high_st = 0.6f;
    brl_enable = 1;
    brl = 0.0f;
    brl_r = -2.5f;
    brl_g = -1.5f;
    brl_b = -1.5f;
    brl_rng = 0.5f;
    brl_st = 0.35f;
    brlp_enable = 1;
    brlp = 0.0f;
    brlp_r = -1.7f;
    brlp_g = -2.0f;
    brlp_b = -0.5f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.3f;
    hs_rgb_enable = 1;
    hs_r = 0.6f;
    hs_r_rng = 0.8f;
    hs_g = 0.35f;
    hs_g_rng = 1.0f;
    hs_b = 0.66f;
    hs_b_rng = 1.0f;
    hs_cmy_enable = 1;
    hs_c = 0.15f;
    hs_c_rng = 1.0f;
    hs_m = 0.0f;
    hs_m_rng = 1.0f;
    hs_y = 0.0f;
    hs_y_rng = 1.0f;
  } else if (look_preset == 2) { // Sylvan
    tn_con = 1.6f;
    tn_sh = 0.5f;
    tn_toe = 0.01f;
    tn_off = 0.01f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 0.25f;
    tn_lcon_w = 0.75f;
    cwp = 2;
    cwp_lm = 0.25f;
    rs_sa = 0.25f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.15f;
    pt_lml_r = 0.5f;
    pt_lml_g = 0.15f;
    pt_lml_b = 0.1f;
    pt_lmh = 0.25f;
    pt_lmh_r = 0.15f;
    pt_lmh_b = 0.15f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.08f;
    ptl_y = 0.05f;
    ptm_enable = 1;
    ptm_low = 0.5f;
    ptm_low_rng = 0.5f;
    ptm_low_st = 0.5f;
    ptm_high = -0.8f;
    ptm_high_rng = 0.5f;
    ptm_high_st = 0.5f;
    brl_enable = 1;
    brl = -1.0f;
    brl_r = -2.0f;
    brl_g = -2.0f;
    brl_b = 0.0f;
    brl_rng = 0.25f;
    brl_st = 0.25f;
    brlp_enable = 1;
    brlp = -1.0f;
    brlp_r = -0.5f;
    brlp_g = -0.25f;
    brlp_b = -0.25f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.4f;
    hs_rgb_enable = 1;
    hs_r = 0.6f;
    hs_r_rng = 1.15f;
    hs_g = 0.8f;
    hs_g_rng = 1.25f;
    hs_b = 0.6f;
    hs_b_rng = 1.0f;
    hs_cmy_enable = 1;
    hs_c = 0.25f;
    hs_c_rng = 0.25f;
    hs_m = 0.25f;
    hs_m_rng = 0.5f;
    hs_y = 0.35f;
    hs_y_rng = 0.5f;
  } else if (look_preset == 3) { // Colorful
    tn_con = 1.5f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.003f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 0.4f;
    tn_lcon_w = 0.5f;
    cwp = 2;
    cwp_lm = 0.25f;
    rs_sa = 0.35f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.5f;
    pt_lml_r = 1.0f;
    pt_lml_g = 0.0f;
    pt_lml_b = 0.5f;
    pt_lmh = 0.15f;
    pt_lmh_r = 0.15f;
    pt_lmh_b = 0.15f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.06f;
    ptl_y = 0.05f;
    ptm_enable = 1;
    ptm_low = 0.8f;
    ptm_low_rng = 0.5f;
    ptm_low_st = 0.4f;
    ptm_high = -0.8f;
    ptm_high_rng = 0.4f;
    ptm_high_st = 0.4f;
    brl_enable = 1;
    brl = 0.0f;
    brl_r = -1.25f;
    brl_g = -1.25f;
    brl_b = -0.25f;
    brl_rng = 0.3f;
    brl_st = 0.5f;
    brlp_enable = 1;
    brlp = -0.5f;
    brlp_r = -1.25f;
    brlp_g = -1.25f;
    brlp_b = -0.5f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.4f;
    hs_rgb_enable = 1;
    hs_r = 0.5f;
    hs_r_rng = 0.8f;
    hs_g = 0.35f;
    hs_g_rng = 1.0f;
    hs_b = 0.5f;
    hs_b_rng = 1.0f;
    hs_cmy_enable = 1;
    hs_c = 0.25f;
    hs_c_rng = 1.0f;
    hs_m = 0.0f;
    hs_m_rng = 1.0f;
    hs_y = 0.25f;
    hs_y_rng = 1.0f;
  } else if (look_preset == 4) { // Aery
    tn_con = 1.15f;
    tn_sh = 0.5f;
    tn_toe = 0.04f;
    tn_off = 0.006f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 0.5f;
    tn_lcon_enable = 1;
    tn_lcon = 0.5f;
    tn_lcon_w = 2.0f;
    cwp = 1;
    cwp_lm = 0.25f;
    rs_sa = 0.25f;
    rs_rw = 0.2f;
    rs_bw = 0.5f;
    pt_enable = 1;
    pt_lml = 0.0f;
    pt_lml_r = 0.5f;
    pt_lml_g = 0.15f;
    pt_lml_b = 0.1f;
    pt_lmh = 0.0f;
    pt_lmh_r = 0.1f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.08f;
    ptl_y = 0.05f;
    ptm_enable = 1;
    ptm_low = 0.8f;
    ptm_low_rng = 0.35f;
    ptm_low_st = 0.5f;
    ptm_high = -0.9f;
    ptm_high_rng = 0.5f;
    ptm_high_st = 0.3f;
    brl_enable = 1;
    brl = -3.0f;
    brl_r = 0.0f;
    brl_g = 0.0f;
    brl_b = 1.0f;
    brl_rng = 0.8f;
    brl_st = 0.15f;
    brlp_enable = 1;
    brlp = -1.0f;
    brlp_r = -1.0f;
    brlp_g = -1.0f;
    brlp_b = 0.0f;
    hc_enable = 1;
    hc_r = 0.5f;
    hc_r_rng = 0.25f;
    hs_rgb_enable = 1;
    hs_r = 0.6f;
    hs_r_rng = 1.0f;
    hs_g = 0.35f;
    hs_g_rng = 2.0f;
    hs_b = 0.5f;
    hs_b_rng = 1.5f;
    hs_cmy_enable = 1;
    hs_c = 0.35f;
    hs_c_rng = 1.0f;
    hs_m = 0.25f;
    hs_m_rng = 1.0f;
    hs_y = 0.35f;
    hs_y_rng = 0.5f;
  } else if (look_preset == 5) { // Dystopic
    tn_con = 1.6f;
    tn_sh = 0.5f;
    tn_toe = 0.01f;
    tn_off = 0.008f;
    tn_hcon_enable = 1;
    tn_hcon = 0.25f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 1.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 0.75f;
    cwp = 3;
    cwp_lm = 0.25f;
    rs_sa = 0.2f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.15f;
    pt_lml_r = 0.0f;
    pt_lml_g = 0.0f;
    pt_lml_b = 0.0f;
    pt_lmh = 0.0f;
    pt_lmh_r = 0.0f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.08f;
    ptl_y = 0.05f;
    ptm_enable = 1;
    ptm_low = 0.25f;
    ptm_low_rng = 0.25f;
    ptm_low_st = 0.8f;
    ptm_high = -0.8f;
    ptm_high_rng = 0.6f;
    ptm_high_st = 0.25f;
    brl_enable = 1;
    brl = -2.0f;
    brl_r = -2.0f;
    brl_g = -2.0f;
    brl_b = 0.0f;
    brl_rng = 0.35f;
    brl_st = 0.35f;
    brlp_enable = 1;
    brlp = 0.0f;
    brlp_r = -1.0f;
    brlp_g = -1.0f;
    brlp_b = -1.0f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.25f;
    hs_rgb_enable = 1;
    hs_r = 0.7f;
    hs_r_rng = 1.33f;
    hs_g = 1.0f;
    hs_g_rng = 2.0f;
    hs_b = 0.75f;
    hs_b_rng = 2.0f;
    hs_cmy_enable = 1;
    hs_c = 1.0f;
    hs_c_rng = 0.5f;
    hs_m = 1.0f;
    hs_m_rng = 1.0f;
    hs_y = 1.0f;
    hs_y_rng = 0.765f;
  } else if (look_preset == 6) { // Umbra
    tn_con = 1.8f;
    tn_sh = 0.5f;
    tn_toe = 0.001f;
    tn_off = 0.015f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 1.0f;
    cwp = 5;
    cwp_lm = 0.25f;
    rs_sa = 0.35f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.0f;
    pt_lml_r = 0.5f;
    pt_lml_g = 0.0f;
    pt_lml_b = 0.15f;
    pt_lmh = 0.25f;
    pt_lmh_r = 0.25f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.06f;
    ptl_y = 0.05f;
    ptm_enable = 1;
    ptm_low = 0.4f;
    ptm_low_rng = 0.35f;
    ptm_low_st = 0.66f;
    ptm_high = -0.6f;
    ptm_high_rng = 0.45f;
    ptm_high_st = 0.45f;
    brl_enable = 1;
    brl = -2.0f;
    brl_r = -4.5f;
    brl_g = -3.0f;
    brl_b = -4.0f;
    brl_rng = 0.35f;
    brl_st = 0.3f;
    brlp_enable = 1;
    brlp = 0.0f;
    brlp_r = -2.0f;
    brlp_g = -1.0f;
    brlp_b = -0.5f;
    hc_enable = 1;
    hc_r = 1.0f;
    hc_r_rng = 0.35f;
    hs_rgb_enable = 1;
    hs_r = 0.66f;
    hs_r_rng = 1.0f;
    hs_g = 0.5f;
    hs_g_rng = 2.0f;
    hs_b = 0.85f;
    hs_b_rng = 2.0f;
    hs_cmy_enable = 1;
    hs_c = 0.0f;
    hs_c_rng = 1.0f;
    hs_m = 0.25f;
    hs_m_rng = 1.0f;
    hs_y = 0.66f;
    hs_y_rng = 0.66f;
  } else if (look_preset == 7) { // Base
    tn_con = 1.66f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.005f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 0;
    tn_lcon = 0.0f;
    tn_lcon_w = 0.5f;
    cwp = 2;
    cwp_lm = 0.25f;
    rs_sa = 0.35f;
    rs_rw = 0.25f;
    rs_bw = 0.55f;
    pt_enable = 1;
    pt_lml = 0.5f;
    pt_lml_r = 0.5f;
    pt_lml_g = 0.15f;
    pt_lml_b = 0.15f;
    pt_lmh = 0.8f;
    pt_lmh_r = 0.5f;
    pt_lmh_b = 0.0f;
    ptl_enable = 1;
    ptl_c = 0.05f;
    ptl_m = 0.06f;
    ptl_y = 0.05f;
    ptm_enable = 0;
    ptm_low = 0.0f;
    ptm_low_rng = 0.5f;
    ptm_low_st = 0.5f;
    ptm_high = 0.0f;
    ptm_high_rng = 0.5f;
    ptm_high_st = 0.5f;
    brl_enable = 0;
    brl = 0.0f;
    brl_r = 0.0f;
    brl_g = 0.0f;
    brl_b = 0.0f;
    brl_rng = 0.5f;
    brl_st = 0.35f;
    brlp_enable = 1;
    brlp = -0.5f;
    brlp_r = -1.6f;
    brlp_g = -1.6f;
    brlp_b = -0.8f;
    hc_enable = 0;
    hc_r = 0.0f;
    hc_r_rng = 0.25f;
    hs_rgb_enable = 0;
    hs_r = 0.0f;
    hs_r_rng = 1.0f;
    hs_g = 0.0f;
    hs_g_rng = 1.0f;
    hs_b = 0.0f;
    hs_b_rng = 1.0f;
    hs_cmy_enable = 0;
    hs_c = 0.0f;
    hs_c_rng = 1.0f;
    hs_m = 0.0f;
    hs_m_rng = 1.0f;
    hs_y = 0.0f;
    hs_y_rng = 1.0f;
  }

  /*----------- TONESCALE PRESETS -----------------*/
  // if (tonescale_preset==0) // Do nothing and use tonescale settings from the
  // look preset

  if (tonescale_preset == 1) { // Low Contrast
    tn_con = 1.4f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.005f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 0;
    tn_lcon = 0.0f;
    tn_lcon_w = 0.5f;
  }
  if (tonescale_preset == 2) { // Medium Contrast
    tn_con = 1.66f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.005f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 0;
    tn_lcon = 0.0f;
    tn_lcon_w = 0.5f;
  }
  if (tonescale_preset == 3) { // High Contrast
    tn_con = 1.4f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.005f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 0.5f;
  } else if (tonescale_preset == 4) { // Arriba Tonescale
    tn_con = 1.05f;
    tn_sh = 0.5f;
    tn_toe = 0.1f;
    tn_off = 0.01f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.5f;
    tn_lcon_w = 0.2f;
  } else if (tonescale_preset == 5) { // Sylvan Tonescale
    tn_con = 1.6f;
    tn_sh = 0.5f;
    tn_toe = 0.01f;
    tn_off = 0.01f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 0.25f;
    tn_lcon_w = 0.75f;
  } else if (tonescale_preset == 6) { // Colorful Tonescale
    tn_con = 1.5f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.003f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 0.4f;
    tn_lcon_w = 0.5f;
  } else if (tonescale_preset == 7) { // Aery Tonescale
    tn_con = 1.15f;
    tn_sh = 0.5f;
    tn_toe = 0.04f;
    tn_off = 0.006f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 0.5f;
    tn_lcon_enable = 1;
    tn_lcon = 0.5f;
    tn_lcon_w = 2.0f;
  } else if (tonescale_preset == 8) { // Dystopic Tonescale
    tn_con = 1.6f;
    tn_sh = 0.5f;
    tn_toe = 0.01f;
    tn_off = 0.008f;
    tn_hcon_enable = 1;
    tn_hcon = 0.25f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 1.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 0.75f;
  } else if (tonescale_preset == 9) { // Umbra Tonescale
    tn_con = 1.8f;
    tn_sh = 0.5f;
    tn_toe = 0.001f;
    tn_off = 0.015f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 1.0f;
  } else if (tonescale_preset == 10) { // ACES-1.x
    tn_con = 1.0f;
    tn_sh = 0.35f;
    tn_toe = 0.02f;
    tn_off = 0.0f;
    tn_hcon_enable = 1;
    tn_hcon = 0.55f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 2.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.13f;
    tn_lcon_w = 1.0f;
  } else if (tonescale_preset == 11) { // ACES-2.0
    tn_con = 1.15f;
    tn_sh = 0.5f;
    tn_toe = 0.04f;
    tn_off = 0.0f;
    tn_hcon_enable = 0;
    tn_hcon = 1.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 1.0f;
    tn_lcon_enable = 0;
    tn_lcon = 1.0f;
    tn_lcon_w = 0.6f;
  } else if (tonescale_preset == 12) { // Marvelous Tonescape
    tn_con = 1.5f;
    tn_sh = 0.5f;
    tn_toe = 0.003f;
    tn_off = 0.01f;
    tn_hcon_enable = 1;
    tn_hcon = 0.25f;
    tn_hcon_pv = 0.0f;
    tn_hcon_st = 4.0f;
    tn_lcon_enable = 1;
    tn_lcon = 1.0f;
    tn_lcon_w = 1.0f;
  } else if (tonescale_preset == 13) { // DaGrinchi Tonegroan
    tn_con = 1.2f;
    tn_sh = 0.5f;
    tn_toe = 0.02f;
    tn_off = 0.0f;
    tn_hcon_enable = 0;
    tn_hcon = 0.0f;
    tn_hcon_pv = 1.0f;
    tn_hcon_st = 1.0f;
    tn_lcon_enable = 0;
    tn_lcon = 0.0f;
    tn_lcon_w = 0.6f;
  }

  // Hard-code clamp if in presets mode
  clamp = 1;

  /*----------- CREATIVE WHITE PRESETS -----------------*/
  if (_cwp != 0)
    cwp_lm = _cwp_lm;
  // if (_cwp==0) // Use cwp from look preset above
  if (_cwp == 1)
    cwp = 0; // D93
  else if (_cwp == 2)
    cwp = 1; // D75
  else if (_cwp == 3)
    cwp = 2; // D65
  else if (_cwp == 4)
    cwp = 3; // D60
  else if (_cwp == 5)
    cwp = 4; // D55
  else if (_cwp == 6)
    cwp = 5; // D50

  /*----------- DISPLAY ENCODING PRESETS -----------------
    display gamut:
      0. Rec.709
      1. P3D65
      2. Rec.2020
      3. P3-D60
      4. P3-DCI
      5. XYZ

    display eotf:
      0. Linear
      1. 2.2 Power sRGB Display
      2. 2.4 Power Rec.1886
      3. 2.6 Power DCI
      4. ST 2084 PQ
      5. HLG
  */

  if (display_encoding_preset == 0) { // Rec.1886
    tn_su = 1;
    display_gamut = 0;
    eotf = 2;
  } else if (display_encoding_preset == 1) { // sRGB Display
    tn_su = 2;
    display_gamut = 0;
    eotf = 1;
  } else if (display_encoding_preset == 2) { // Display P3
    tn_su = 2;
    display_gamut = 1;
    eotf = 1;
  } else if (display_encoding_preset == 3) { // P3-D60
    tn_su = 0;
    display_gamut = 3;
    eotf = 3;
  } else if (display_encoding_preset == 4) { // P3-DCI
    tn_su = 0;
    display_gamut = 4;
    eotf = 3;
  } else if (display_encoding_preset == 5) { // DCI P3 XYZ
    tn_su = 0;
    display_gamut = 5;
    eotf = 3;
  } else if (display_encoding_preset == 6) { // Rec.2100 PQ
    tn_su = 0;
    display_gamut = 2;
    eotf = 4;
  } else if (display_encoding_preset == 7) { // Rec.2100 HLG
    tn_su = 0;
    display_gamut = 2;
    eotf = 5;
  } else if (display_encoding_preset == 8) { // Dolby PQ
    tn_su = 0;
    display_gamut = 1;
    eotf = 4;
  }

  float3x3 in_to_xyz;
  if (in_gamut == 0)
    in_to_xyz = identity();
  else if (in_gamut == 1)
    in_to_xyz = matrix_ap0_to_xyz;
  else if (in_gamut == 2)
    in_to_xyz = matrix_ap1_to_xyz;
  else if (in_gamut == 3)
    in_to_xyz = matrix_p3d65_to_xyz;
  else if (in_gamut == 4)
    in_to_xyz = matrix_rec2020_to_xyz;
  else if (in_gamut == 5)
    in_to_xyz = matrix_rec709_to_xyz;
  else if (in_gamut == 6)
    in_to_xyz = matrix_arriwg3_to_xyz;
  else if (in_gamut == 7)
    in_to_xyz = matrix_arriwg4_to_xyz;
  else if (in_gamut == 8)
    in_to_xyz = matrix_redwg_to_xyz;
  else if (in_gamut == 9)
    in_to_xyz = matrix_sonysgamut3_to_xyz;
  else if (in_gamut == 10)
    in_to_xyz = matrix_sonysgamut3cine_to_xyz;
  else if (in_gamut == 11)
    in_to_xyz = matrix_vgamut_to_xyz;
  else if (in_gamut == 12)
    in_to_xyz = matrix_egamut_to_xyz;
  else if (in_gamut == 13)
    in_to_xyz = matrix_egamut2_to_xyz;
  else if (in_gamut == 14)
    in_to_xyz = matrix_davinciwg_to_xyz;

  // Linearize if a non-linear input oetf / transfer function is selected
  rgb = linearize(rgb, in_oetf);

  /***************************************************
    Tonescale Constraint Calculations
    https://www.desmos.com/calculator/1c4fhzy3bw

    These should be pre-calculated but there is no way to do this in DCTL.
    Anything that is const should be precalculated and not run per-pixel
    --------------------------------------------------*/
  const float ts_x1 = _powf(2.0f, 6.0f * tn_sh + 4.0f);
  const float ts_y1 = tn_Lp / 100.0f;
  const float ts_x0 = 0.18f + tn_off;
  const float ts_y0 = tn_Lg / 100.0f * (1.0f + tn_gb * _log2f(ts_y1));
  const float ts_s0 = compress_toe_quadratic(ts_y0, tn_toe, 1);
  const float ts_p =
      tn_con /
      (1.0f + (float)tn_su * 0.05f); // unconstrained surround compensation
  const float ts_s10 = ts_x0 * (_powf(ts_s0, -1.0f / tn_con) - 1.0f);
  const float ts_m1 = ts_y1 / _powf(ts_x1 / (ts_x1 + ts_s10), tn_con);
  const float ts_m2 = compress_toe_quadratic(ts_m1, tn_toe, 1);
  const float ts_s = ts_x0 * (_powf(ts_s0 / ts_m2, -1.0f / tn_con) - 1.0f);
  const float ts_dsc = eotf == 4 ? 0.01 : eotf == 5 ? 0.1 : 100.0f / tn_Lp;

  // Lerp from pt_cmp at 100 nits to pt_cmp_hdr at 1000 nits
  const float pt_cmp_Lf = pt_hdr * _fminf(1.0f, (tn_Lp - 100.0f) / 900.0f);
  // Approximate scene-linear scale at Lp=100 nits
  const float s_Lp100 =
      ts_x0 * (_powf((tn_Lg / 100.0f), -1.0f / tn_con) - 1.0f);
  const float ts_s1 = ts_s * pt_cmp_Lf + s_Lp100 * (1.0f - pt_cmp_Lf);

  // Convert from input gamut into P3-D65
  rgb = vdot(in_to_xyz, rgb);
  rgb = vdot(matrix_xyz_to_p3d65, rgb);

  // Rendering Space: "Desaturate" to control scale of the color volume in the
  // rgb ratios. Controlled by rs_sa (saturation) and red and blue weights
  // (rs_rw and rs_bw)
  float3 rs_w = make_float3(rs_rw, 1.0f - rs_rw - rs_bw, rs_bw);
  float sat_L = rgb.x * rs_w.x + rgb.y * rs_w.y + rgb.z * rs_w.z;
  rgb = sat_L * rs_sa + rgb * (1.0f - rs_sa);

  // Offset
  rgb += tn_off;

  // Tonescale Norm
  float tsn = hypotf3(rgb) / SQRT3;

  // RGB Ratios
  rgb = sdivf3f(rgb, tsn);

  float2 opp = opponent(rgb);
  float ach_d = hypotf2(opp) / 2.0f;

  // Smooth ach_d, normalized so 1.0 doesn't change
  // https://www.desmos.com/calculator/ozjg09hzef
  ach_d = (1.25f) * compress_toe_quadratic(ach_d, 0.25f, 0);

  // Hue angle, rotated so that red = 0.0
  float hue = _fmod(_atan2f(opp.x, opp.y) + PI + 1.10714931f, 2.0f * PI);

  // RGB Hue Angles
  // Wider than CMY by default. R towards M, G towards Y, B towards C
  float3 ha_rgb = make_float3(gauss_window(hue_offset(hue, 0.1f), 0.66f),
                              gauss_window(hue_offset(hue, 4.3f), 0.66f),
                              gauss_window(hue_offset(hue, 2.3f), 0.66f));

  // RGB Hue Angles for hue shift: red shifted more orange
  float3 ha_rgb_hs =
      make_float3(gauss_window(hue_offset(hue, -0.4f), 0.66f), ha_rgb.y,
                  gauss_window(hue_offset(hue, 2.5f), 0.66f));

  // CMY Hue Angles
  // Exact alignment to Cyan/Magenta/Yellow secondaries would be PI, PI/3 and
  // -PI/3, but we customize these a bit for creative purposes: M towards B, Y
  // towards G, C towards G
  float3 ha_cmy = make_float3(gauss_window(hue_offset(hue, 3.3f), 0.5f),
                              gauss_window(hue_offset(hue, 1.3f), 0.5f),
                              gauss_window(hue_offset(hue, -1.15f), 0.5f));

  // Brilliance
  if (brl_enable > 0) {
    float brl_tsf = _powf(tsn / (tsn + 1.0f), 1.0f - brl_rng);
    float brl_exf =
        (brl + brl_r * ha_rgb.x + brl_g * ha_rgb.y + brl_b * ha_rgb.z) *
        _powf(ach_d, 1.0f / brl_st);
    float brl_ex =
        _powf(2.0f, brl_exf * (brl_exf < 0.0f ? brl_tsf : 1.0f - brl_tsf));
    tsn *= brl_ex;
  }

  // Contrast Low
  if (tn_lcon_enable > 0) {
    float lcon_m = _powf(2.0f, -tn_lcon);
    float lcon_w = tn_lcon_w / 4.0f;
    lcon_w *= lcon_w;

    // Normalize for ts_x0 intersection constraint:
    // https://www.desmos.com/calculator/blyvi8t2b2
    const float lcon_cnst_sc =
        compress_toe_cubic(ts_x0, lcon_m, lcon_w, 1) / ts_x0;
    tsn *= lcon_cnst_sc;
    tsn = compress_toe_cubic(tsn, lcon_m, lcon_w, 0);
  }

  // Contrast High
  if (tn_hcon_enable > 0) {
    float hcon_p = _powf(2.0f, tn_hcon);
    tsn = contrast_high(tsn, hcon_p, tn_hcon_pv, tn_hcon_st, 0);
  }

  // Hyperbolic Compression
  float tsn_pt = compress_hyperbolic_power(tsn, ts_s1, ts_p);
  float tsn_const = compress_hyperbolic_power(tsn, s_Lp100, ts_p);
  tsn = compress_hyperbolic_power(tsn, ts_s, ts_p);

  /***************************************************
    Hue Contrast R
  --------------------------------------------------*/
  if (hc_enable > 0) {
    float hc_ts = 1.0f - tsn_const;
    // Limit high purity on bottom end and low purity on top end by ach_d.
    // This helps reduce artifacts and over-saturation.
    float hc_c = hc_ts * (1.0f - ach_d) + ach_d * (1.0f - hc_ts);
    hc_c *= ach_d * ha_rgb.x;
    hc_ts = _powf(hc_ts, 1.0f / hc_r_rng);
    // Bias contrast based on tonescale using Lift/Mult:
    // https://www.desmos.com/calculator/gzbgov62hl
    float hc_f = hc_r * (hc_c - 2.0f * hc_c * hc_ts) + 1.0f;
    rgb = make_float3(rgb.x, rgb.y * hc_f, rgb.z * hc_f);
  }

  /***************************************************
    Hue Shift
  --------------------------------------------------*/
  // Hue Shift RGB by purity compress tonescale, shifting more as intensity
  // increases
  if (hs_rgb_enable > 0) {
    float3 hs_rgb =
        make_float3(ha_rgb_hs.x * ach_d * _powf(tsn_pt, 1.0f / hs_r_rng),
                    ha_rgb_hs.y * ach_d * _powf(tsn_pt, 1.0f / hs_g_rng),
                    ha_rgb_hs.z * ach_d * _powf(tsn_pt, 1.0f / hs_b_rng));
    float3 hsf =
        make_float3(hs_rgb.x * hs_r, hs_rgb.y * -hs_g, hs_rgb.z * -hs_b);
    hsf = make_float3(hsf.z - hsf.y, hsf.x - hsf.z, hsf.y - hsf.x);
    rgb += hsf;
  }

  // Hue Shift CMY by tonescale, shifting less as intensity increases
  if (hs_cmy_enable > 0) {
    float tsn_pt_compl = 1.0f - tsn_pt;
    float3 hs_cmy =
        make_float3(ha_cmy.x * ach_d * _powf(tsn_pt_compl, 1.0f / hs_c_rng),
                    ha_cmy.y * ach_d * _powf(tsn_pt_compl, 1.0f / hs_m_rng),
                    ha_cmy.z * ach_d * _powf(tsn_pt_compl, 1.0f / hs_y_rng));
    float3 hsf =
        make_float3(hs_cmy.x * -hs_c, hs_cmy.y * hs_m, hs_cmy.z * hs_y);
    hsf = make_float3(hsf.z - hsf.y, hsf.x - hsf.z, hsf.y - hsf.x);
    rgb += hsf;
  }

  /***************************************************
    Purity Compression
      https://www.desmos.com/calculator/adtzkjofgn
  --------------------------------------------------*/
  // Purity Limit Low
  float pt_lml_p = 1.0f + 4.0f * (1.0f - tsn_pt) *
                              (pt_lml + pt_lml_r * ha_rgb_hs.x +
                               pt_lml_g * ha_rgb_hs.y + pt_lml_b * ha_rgb_hs.z);
  float ptf = 1.0f - _powf(tsn_pt, pt_lml_p);

  // Purity Limit High
  float pt_lmh_p =
      (1.0f - ach_d * (pt_lmh_r * ha_rgb_hs.x + pt_lmh_b * ha_rgb_hs.z)) *
      (1.0f - pt_lmh * ach_d);
  ptf = _powf(ptf, pt_lmh_p);

  /***************************************************
    Mid-Range Purity
      This boosts mid-range purity on the low end
      and reduces mid-range purity on the high end
  --------------------------------------------------*/
  if (ptm_enable > 0) {
    float ptm_low_f;
    if (ptm_low_st == 0.0f || ptm_low_rng == 0.0f)
      ptm_low_f = 1.0f;
    else
      ptm_low_f = 1.0f + ptm_low * _expf(-2.0f * ach_d * ach_d / ptm_low_st) *
                             _powf(1.0f - tsn_const, 1.0f / ptm_low_rng);
    float ptm_high_f;
    if (ptm_high_st == 0.0f || ptm_high_rng == 0.0f)
      ptm_high_f = 1.0f;
    else
      ptm_high_f = 1.0f + ptm_high *
                              _expf(-2.0f * ach_d * ach_d / ptm_high_st) *
                              _powf(tsn_pt, 1.0f / (4.0f * ptm_high_rng));
    ptf *= ptm_low_f * ptm_high_f;
  }

  // Lerp to peak achromatic by ptf in rgb ratios
  rgb = rgb * ptf + 1.0f - ptf;

  // Inverse Rendering Space
  sat_L = rgb.x * rs_w.x + rgb.y * rs_w.y + rgb.z * rs_w.z;
  rgb = (sat_L * rs_sa - rgb) / (rs_sa - 1.0f);

  // Convert to final display gamut and set whitepoint
  rgb = display_gamut_whitepoint(rgb, tsn_const, cwp_lm, display_gamut, cwp);

  // Post Brilliance
  if (brlp_enable > 0) {
    float2 brlp_opp = opponent(rgb);
    float brlp_ach_d = hypotf2(brlp_opp) / 4.0f;
    // brlp_ach_d = 1.0f - gauss_window(brlp_ach_d, 8.0f);
    brlp_ach_d = 1.1f * (brlp_ach_d * brlp_ach_d / (brlp_ach_d + 0.1f));
    float3 brlp_ha_rgb = ach_d * ha_rgb;
    float brlp_m = brlp + brlp_r * brlp_ha_rgb.x + brlp_g * brlp_ha_rgb.y +
                   brlp_b * brlp_ha_rgb.z;
    float brlp_ex = _powf(2.0f, brlp_m * brlp_ach_d * tsn);
    rgb *= brlp_ex;
  }

  // Purity Compress Low
  if (ptl_enable > 0)
    rgb = make_float3(softplus(rgb.x, ptl_c), softplus(rgb.y, ptl_m),
                      softplus(rgb.z, ptl_y));

  // Final tonescale adjustments
  tsn *= ts_m2; // scale for inverse toe
  tsn = compress_toe_quadratic(tsn, tn_toe, 0);
  tsn *= ts_dsc; // scale for display encoding

  // Return from RGB ratios
  rgb *= tsn;

  // Rec.2020 (P3 Limited)
  if (display_gamut == 2) {
    rgb = clampminf3(rgb, 0.0f); // Limit to P3 gamut
    rgb = vdot(matrix_p3_to_rec2020, rgb);
  }

  // Clamp
  if (clamp > 0)
    rgb = clampf3(rgb, 0.0f, 1.0f);

  // Apply inverse Display EOTF
  float eotf_p = 2.0f + eotf * 0.2f;
  if ((eotf > 0) && (eotf < 4))
    rgb = spowf3(rgb, 1.0f / eotf_p);
  else if (eotf == 4)
    rgb = eotf_pq(rgb, 1);
  else if (eotf == 5)
    rgb = eotf_hlg(rgb, 1);

  return rgb;
}
