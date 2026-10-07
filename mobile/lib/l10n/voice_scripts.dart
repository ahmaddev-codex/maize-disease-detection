import '../constants/diseases.dart';
import '../providers/app_provider.dart' show DisplayLanguage;

/// Spoken treatment scripts, built from the one actives table so that Rust says
/// triazole in Hausa, Yoruba, Igbo and English alike. The hand-written scripts
/// they replace named Ridomil Gold and Funguran — products that do not control
/// any of these fungi — in three languages (T25).
String treatmentScript(
  DisplayLanguage lang,
  DiseaseInfo disease, {
  required bool isLowConfidence,
}) {
  if (isLowConfidence) return _uncertainScript(lang);
  if (disease.classId == kHealthyClassId) return _healthyScript(lang);

  final active = disease.actives.isNotEmpty ? disease.actives.first : '';
  return switch (lang) {
    DisplayLanguage.yoruba =>
      'Eto itoju fun arun ${disease.name}. Ni akoko, e wa ogun ti o ni $active, '
          'ki e si ka iwe ilana lori igo naa fun iwon to tona. Ni ekeji, e fe e ni owuro '
          'kutukutu ki oorun to mu. Ni eketa, e ja awon ewe ti arun ba je ki e si sun won. '
          'E ba osise ogbin soro lati fi idi ogun naa mule.',
    DisplayLanguage.hausa =>
      'Shirin maganin cutar ${disease.name}. Da farko, a nemi magani mai dauke da $active, '
          'a kuma karanta umarnin da ke jikin kwalbar don sanin adadin da ya dace. Na biyu, '
          'a fesa da sassafe kafin rana ta yi zafi. Na uku, a cire ganyayen da cutar ta lalata '
          'a kona su. A tuntubi jami\'in aikin gona domin tabbatarwa.',
    DisplayLanguage.igbo =>
      'Atumatu ogwugwo maka oria ${disease.name}. Nke mbu, choo ogwu nwere $active, '
          'gukwaa ntuziaka di na karama ya maka ogo kwesiri. Nke abuo, fesaa ya n\'isi ututu '
          'tupu anwu ekpo oku. Nke ato, wepu akwukwo ndi oria mebiri ma kpoo ha oku. '
          'Kparita ukwu na onye nkuzi oru ugbo iji kwado ya.',
    DisplayLanguage.english =>
      'Recommended treatment plan for ${disease.name}. First, look for a fungicide '
          'containing $active, and follow the rate and pre-harvest interval printed on the '
          'product label. Second, spray in the early morning before the heat of the day. '
          'Third, remove and destroy badly infected leaves. Confirm the product choice with '
          'your local extension officer.',
  };
}

String _healthyScript(DisplayLanguage lang) => switch (lang) {
      DisplayLanguage.yoruba =>
        'Eto itoju: Ko nilo ogun kankan fun agbado yi. E fa koriko kuro, ki e si se ayewo '
            'oko lorekore ni gbogbo ose.',
      DisplayLanguage.hausa =>
        'Shirin kulawa: Ba a bukatar wani magani a yanzu. A cire ciyawa, a kuma duba gonar '
            'kowane mako.',
      DisplayLanguage.igbo =>
        'Atumatu nlekota: O dighi ogwu di mkpa ugbu a. Wepu ahihia ma na-elele ubi gi kwa izu.',
      DisplayLanguage.english =>
        'Care plan: no fungicide is needed for this plant. Keep the borders weed free and '
            'scout the field again in about a week.',
    };

String _uncertainScript(DisplayLanguage lang) => switch (lang) {
      DisplayLanguage.yoruba =>
        'A ko le so arun na daju lati ara aworan yi. E tun ya aworan ewe kan soso ninu imole '
            'osan, laisi ojiji. E ma lo ogun kankan titi di igba ti a fi mo arun na.',
      DisplayLanguage.hausa =>
        'Ba mu iya tantance cutar daga wannan hoton ba. A sake daukar hoton ganye guda daya '
            'cikin haske mai kyau, ba tare da inuwa ba. Kada a yi amfani da kowane magani '
            'sai an tabbatar da cutar.',
      DisplayLanguage.igbo =>
        'Anyi enweghi ike ikwu oria a n\'ezie site na foto a. Sepụta foto ozo nke otu akwukwo '
            'n\'ihe nchoputa di mma, na-enweghi ndo. Ejila ogwu obula ruo mgbe a kwadoro oria ahu.',
      DisplayLanguage.english =>
        'This photo was not clear enough to diagnose. Take another one of a single leaf in '
            'even daylight, with no shadow or glare. Do not apply any chemical until the '
            'diagnosis is confirmed.',
    };
