
import groovy.json.JsonSlurper
def jsonSlurper = new JsonSlurper()

List<String> extractTaskIDforFile(Path filepath, String task_name) {
  String filename = filepath as String
  filename = filename[filename.lastIndexOf('/')+1..-1]

  List<String> ids_for_file = new ArrayList<String>()
  for (destination : file_inputs[filename]) {
    def destination_task_name = destination[0]
    def destination_task_id = destination[1]
    if (destination_task_name == task_name)
      ids_for_file.add(destination_task_id)
  }
  return ids_for_file
}

// define amount of input files for abstracts tasks where the amount is not constant
def haplotype_caller_input_amounts = [
  "00000007": 12,
  "00000008": 12,
  "00000009": 12,
  "00000010": 12,
  "00000011": 12,
  "00000012": 12,
  "00000013": 12,
  "00000014": 12,
  "00000015": 12,
  "00000016": 12,
  "00000023": 12,
  "00000024": 12,
  "00000025": 12,
  "00000026": 12,
  "00000027": 12,
  "00000028": 12,
  "00000029": 12,
  "00000030": 12,
  "00000031": 12,
  "00000032": 12,
  "00000039": 12,
  "00000040": 12,
  "00000041": 12,
  "00000042": 12,
  "00000043": 12,
  "00000044": 12,
  "00000045": 12,
  "00000046": 12,
  "00000047": 12,
  "00000048": 12,
  "00000055": 12,
  "00000056": 12,
  "00000057": 12,
  "00000058": 12,
  "00000059": 12,
  "00000060": 12,
  "00000061": 12,
  "00000062": 12,
  "00000063": 12,
  "00000064": 12,
  "00000071": 12,
  "00000072": 12,
  "00000073": 12,
  "00000074": 12,
  "00000075": 12,
  "00000076": 12,
  "00000077": 12,
  "00000078": 12,
  "00000079": 12,
  "00000080": 12,
  "00000087": 12,
  "00000088": 12,
  "00000089": 12,
  "00000090": 12,
  "00000091": 12,
  "00000092": 12,
  "00000093": 12,
  "00000094": 12,
  "00000095": 12,
  "00000096": 12,
  "00000103": 12,
  "00000104": 12,
  "00000105": 12,
  "00000106": 12,
  "00000107": 12,
  "00000108": 12,
  "00000109": 12,
  "00000110": 12,
  "00000111": 12,
  "00000112": 12,
  "00000119": 12,
  "00000120": 12,
  "00000121": 12,
  "00000122": 12,
  "00000123": 12,
  "00000124": 12,
  "00000125": 12,
  "00000126": 12,
  "00000127": 12,
  "00000128": 12,
  "00000135": 12,
  "00000136": 12,
  "00000137": 12,
  "00000138": 12,
  "00000139": 12,
  "00000140": 12,
  "00000141": 12,
  "00000142": 12,
  "00000143": 12,
  "00000144": 12,
  "00000151": 12,
  "00000152": 12,
  "00000153": 12,
  "00000154": 12,
  "00000155": 12,
  "00000156": 12,
  "00000157": 12,
  "00000158": 12,
  "00000159": 12,
  "00000160": 12,
  "00000167": 12,
  "00000168": 12,
  "00000169": 12,
  "00000170": 12,
  "00000171": 12,
  "00000172": 12,
  "00000173": 12,
  "00000174": 12,
  "00000175": 12,
  "00000176": 12,
  "00000183": 12,
  "00000184": 12,
  "00000185": 12,
  "00000186": 12,
  "00000187": 12,
  "00000188": 12,
  "00000189": 12,
  "00000190": 12,
  "00000191": 12,
  "00000192": 12,
  "00000199": 12,
  "00000200": 12,
  "00000201": 12,
  "00000202": 12,
  "00000203": 12,
  "00000204": 12,
  "00000205": 12,
  "00000206": 12,
  "00000207": 12,
  "00000208": 12,
  "00000215": 12,
  "00000216": 12,
  "00000217": 12,
  "00000218": 12,
  "00000219": 12,
  "00000220": 12,
  "00000221": 12,
  "00000222": 12,
  "00000223": 12,
  "00000224": 12,
  "00000231": 12,
  "00000232": 12,
  "00000233": 12,
  "00000234": 12,
  "00000235": 12,
  "00000236": 12,
  "00000237": 12,
  "00000238": 12,
  "00000239": 12,
  "00000240": 12,
  "00000257": 12,
  "00000258": 18,
  "00000259": 18,
  "00000260": 24,
  "00000261": 20,
  "00000263": 22,
  "00000264": 20,
  "00000265": 22,
  "00000266": 14,
  "00000267": 14,
  "00000268": 26,
  "00000269": 16,
  "00000270": 18,
  "00000271": 24,
  "00000272": 20,
  "00000273": 12,
  "00000276": 12,
  "00000277": 12,
  "00000278": 12,
  "00000279": 12,
  "00000282": 12,
  "00000284": 12,
  "00000285": 12,
  "00000286": 12,
  "00000288": 12,
  "00000289": 12,
  "00000290": 18,
  "00000291": 18,
  "00000292": 24,
  "00000293": 18,
  "00000295": 22,
  "00000296": 20,
  "00000297": 22,
  "00000298": 14,
  "00000299": 14,
  "00000300": 26,
  "00000301": 16,
  "00000302": 18,
  "00000303": 24,
  "00000304": 20,
  "00000305": 26,
  "00000306": 22,
  "00000307": 24,
  "00000308": 14,
  "00000309": 12,
  "00000310": 24,
  "00000311": 20,
  "00000312": 18,
  "00000313": 18,
  "00000315": 22,
  "00000316": 16,
  "00000317": 14,
  "00000318": 18,
  "00000319": 18,
  "00000320": 20,
  "00000322": 18,
  "00000323": 24,
  "00000324": 26,
  "00000325": 20,
  "00000326": 18,
  "00000327": 22,
  "00000328": 12,
  "00000329": 24,
  "00000330": 16,
  "00000331": 18,
  "00000332": 22,
  "00000333": 14,
  "00000334": 20,
  "00000335": 14,
  "00000336": 18,
  "00000337": 12,
  "00000338": 12,
  "00000343": 12,
  "00000344": 12,
  "00000346": 12,
  "00000348": 12,
  "00000349": 12,
  "00000350": 12,
  "00000351": 12,
  "00000352": 12,
  "00000353": 12,
  "00000356": 12,
  "00000357": 12,
  "00000358": 12,
  "00000359": 12,
  "00000362": 12,
  "00000364": 12,
  "00000365": 12,
  "00000366": 12,
  "00000368": 12,
  "00000369": 12,
  "00000372": 12,
  "00000373": 12,
  "00000374": 12,
  "00000375": 12,
  "00000378": 12,
  "00000380": 12,
  "00000381": 12,
  "00000383": 12,
  "00000384": 12,
  "00000385": 12,
  "00000388": 12,
  "00000390": 12,
  "00000391": 12,
  "00000393": 12,
  "00000394": 12,
  "00000395": 12,
  "00000397": 12,
  "00000398": 12,
  "00000399": 12,
  "00000401": 18,
  "00000402": 18,
  "00000403": 16,
  "00000404": 14,
  "00000405": 20,
  "00000406": 24,
  "00000407": 22,
  "00000408": 18,
  "00000409": 16,
  "00000410": 26,
  "00000411": 24,
  "00000412": 14,
  "00000413": 12,
  "00000414": 20,
  "00000416": 16,
  "00000417": 12,
  "00000420": 12,
  "00000421": 12,
  "00000422": 12,
  "00000423": 12,
  "00000426": 12,
  "00000428": 12,
  "00000429": 12,
  "00000430": 12,
  "00000432": 12,
  "00000434": 12,
  "00000435": 12,
  "00000436": 12,
  "00000437": 12,
  "00000438": 12,
  "00000439": 12,
  "00000441": 12,
  "00000443": 12,
  "00000444": 12,
  "00000445": 12,
  "00000450": 12,
  "00000453": 12,
  "00000454": 12,
  "00000455": 12,
  "00000456": 12,
  "00000458": 12,
  "00000459": 12,
  "00000461": 12,
  "00000462": 12,
  "00000464": 12,
  "00000465": 24,
  "00000466": 20,
  "00000467": 24,
  "00000468": 14,
  "00000469": 12,
  "00000470": 22,
  "00000471": 18,
  "00000472": 18,
  "00000473": 14,
  "00000475": 22,
  "00000476": 16,
  "00000477": 14,
  "00000478": 18,
  "00000479": 16,
  "00000480": 20,
  "00000482": 12,
  "00000483": 12,
  "00000484": 12,
  "00000485": 12,
  "00000486": 12,
  "00000488": 12,
  "00000492": 12,
  "00000493": 12,
  "00000494": 12,
  "00000496": 12,
  "00000497": 16,
  "00000498": 20,
  "00000499": 20,
  "00000500": 18,
  "00000502": 12,
  "00000503": 22,
  "00000504": 24,
  "00000505": 18,
  "00000506": 22,
  "00000507": 14,
  "00000508": 18,
  "00000509": 16,
  "00000510": 22,
  "00000511": 14,
  "00000512": 14,
  "00000513": 12,
  "00000514": 12,
  "00000519": 12,
  "00000520": 12,
  "00000522": 12,
  "00000524": 12,
  "00000525": 12,
  "00000526": 12,
  "00000527": 12,
  "00000528": 12,
  "00000529": 24,
  "00000530": 20,
  "00000531": 22,
  "00000532": 14,
  "00000533": 12,
  "00000534": 22,
  "00000535": 16,
  "00000536": 18,
  "00000537": 14,
  "00000539": 22,
  "00000540": 16,
  "00000541": 14,
  "00000542": 18,
  "00000543": 16,
  "00000544": 20,
  "00000545": 16,
  "00000546": 18,
  "00000547": 14,
  "00000548": 22,
  "00000549": 20,
  "00000550": 18,
  "00000551": 12,
  "00000552": 22,
  "00000553": 24,
  "00000554": 22,
  "00000555": 14,
  "00000556": 14,
  "00000558": 20,
  "00000559": 16,
  "00000560": 16,
  "00000561": 12,
  "00000562": 12,
  "00000566": 12,
  "00000567": 12,
  "00000568": 12,
  "00000570": 12,
  "00000571": 12,
  "00000574": 12,
  "00000575": 12,
  "00000576": 12,
  "00000577": 16,
  "00000578": 18,
  "00000579": 14,
  "00000580": 22,
  "00000581": 20,
  "00000582": 16,
  "00000583": 12,
  "00000584": 22,
  "00000585": 24,
  "00000586": 22,
  "00000587": 14,
  "00000588": 14,
  "00000590": 20,
  "00000591": 16,
  "00000592": 16,
  "00000593": 16,
  "00000594": 20,
  "00000595": 20,
  "00000596": 16,
  "00000598": 12,
  "00000599": 22,
  "00000600": 24,
  "00000601": 16,
  "00000602": 22,
  "00000603": 14,
  "00000604": 18,
  "00000605": 16,
  "00000606": 22,
  "00000607": 14,
  "00000608": 14,
  "00000610": 12,
  "00000611": 12,
  "00000612": 12,
  "00000613": 12,
  "00000614": 12,
  "00000615": 12,
  "00000617": 12,
  "00000619": 12,
  "00000620": 12,
  "00000621": 12,
  "00000625": 20,
  "00000626": 22,
  "00000627": 14,
  "00000628": 20,
  "00000629": 20,
  "00000630": 16,
  "00000631": 14,
  "00000632": 14,
  "00000633": 16,
  "00000634": 22,
  "00000635": 12,
  "00000636": 16,
  "00000637": 16,
  "00000639": 18,
  "00000640": 24,
  "00000642": 12,
  "00000645": 12,
  "00000646": 12,
  "00000647": 12,
  "00000648": 12,
  "00000650": 12,
  "00000651": 12,
  "00000653": 12,
  "00000654": 12,
  "00000656": 12,
  "00000657": 12,
  "00000658": 12,
  "00000659": 12,
  "00000660": 12,
  "00000665": 12,
  "00000666": 12,
  "00000667": 12,
  "00000668": 12,
  "00000669": 12,
  "00000672": 12,
  "00000673": 12,
  "00000676": 12,
  "00000677": 12,
  "00000678": 12,
  "00000679": 12,
  "00000682": 12,
  "00000684": 12,
  "00000685": 12,
  "00000687": 12,
  "00000688": 12,
  "00000689": 20,
  "00000690": 22,
  "00000691": 14,
  "00000692": 20,
  "00000693": 18,
  "00000694": 16,
  "00000695": 14,
  "00000696": 14,
  "00000697": 16,
  "00000698": 22,
  "00000699": 12,
  "00000700": 16,
  "00000701": 16,
  "00000703": 16,
  "00000704": 22,
  "00000706": 12,
  "00000707": 12,
  "00000708": 12,
  "00000709": 12,
  "00000710": 12,
  "00000712": 12,
  "00000716": 12,
  "00000717": 12,
  "00000718": 12,
  "00000720": 12,
  "00000721": 20,
  "00000722": 20,
  "00000723": 14,
  "00000724": 20,
  "00000725": 18,
  "00000726": 16,
  "00000727": 14,
  "00000728": 14,
  "00000729": 16,
  "00000730": 22,
  "00000731": 12,
  "00000732": 16,
  "00000733": 16,
  "00000735": 16,
  "00000736": 22,
  "00000737": 16,
  "00000738": 16,
  "00000739": 16,
  "00000740": 14,
  "00000741": 18,
  "00000742": 20,
  "00000743": 22,
  "00000744": 16,
  "00000745": 16,
  "00000746": 22,
  "00000747": 20,
  "00000748": 14,
  "00000749": 12,
  "00000750": 20,
  "00000752": 14,
  "00000753": 20,
  "00000754": 20,
  "00000755": 14,
  "00000756": 20,
  "00000757": 18,
  "00000758": 16,
  "00000759": 14,
  "00000760": 14,
  "00000761": 16,
  "00000762": 22,
  "00000763": 12,
  "00000764": 16,
  "00000765": 16,
  "00000767": 16,
  "00000768": 22,
  "00000769": 16,
  "00000770": 16,
  "00000771": 16,
  "00000772": 14,
  "00000773": 18,
  "00000774": 20,
  "00000775": 22,
  "00000776": 16,
  "00000777": 16,
  "00000778": 22,
  "00000779": 20,
  "00000780": 14,
  "00000781": 12,
  "00000782": 20,
  "00000784": 14,
  "00000785": 12,
  "00000788": 12,
  "00000789": 12,
  "00000790": 12,
  "00000791": 12,
  "00000794": 12,
  "00000796": 12,
  "00000797": 12,
  "00000799": 12,
  "00000800": 12,
  "00000801": 22,
  "00000802": 16,
  "00000803": 20,
  "00000804": 14,
  "00000805": 12,
  "00000806": 20,
  "00000807": 16,
  "00000808": 16,
  "00000809": 14,
  "00000811": 22,
  "00000812": 16,
  "00000813": 14,
  "00000814": 16,
  "00000815": 16,
  "00000816": 20,
  "00000817": 12,
  "00000820": 12,
  "00000822": 12,
  "00000823": 12,
  "00000825": 12,
  "00000826": 12,
  "00000827": 12,
  "00000829": 12,
  "00000830": 12,
  "00000831": 12,
  "00000833": 14,
  "00000834": 20,
  "00000835": 16,
  "00000836": 16,
  "00000838": 12,
  "00000839": 20,
  "00000840": 22,
  "00000841": 16,
  "00000842": 20,
  "00000843": 14,
  "00000844": 16,
  "00000845": 16,
  "00000846": 22,
  "00000847": 14,
  "00000848": 14,
  "00000849": 12,
  "00000852": 12,
  "00000853": 12,
  "00000854": 12,
  "00000855": 12,
  "00000858": 12,
  "00000860": 12,
  "00000861": 12,
  "00000862": 12,
  "00000864": 12,
  "00000865": 12,
  "00000866": 12,
  "00000867": 12,
  "00000868": 12,
  "00000873": 12,
  "00000874": 12,
  "00000875": 12,
  "00000876": 12,
  "00000877": 12,
  "00000880": 12,
  "00000885": 12,
  "00000886": 12,
  "00000887": 12,
  "00000888": 12,
  "00000889": 12,
  "00000890": 12,
  "00000892": 12,
  "00000893": 12,
  "00000894": 12,
  "00000896": 12,
  "00000897": 22,
  "00000898": 16,
  "00000899": 20,
  "00000900": 14,
  "00000901": 12,
  "00000902": 20,
  "00000903": 16,
  "00000904": 14,
  "00000905": 12,
  "00000907": 20,
  "00000908": 16,
  "00000909": 14,
  "00000910": 16,
  "00000911": 14,
  "00000912": 20,
  "00000913": 12,
  "00000914": 12,
  "00000918": 12,
  "00000919": 12,
  "00000920": 12,
  "00000922": 12,
  "00000923": 12,
  "00000926": 12,
  "00000927": 12,
  "00000928": 12,
  "00000930": 12,
  "00000933": 12,
  "00000934": 12,
  "00000935": 12,
  "00000936": 12,
  "00000938": 12,
  "00000939": 12,
  "00000941": 12,
  "00000942": 12,
  "00000944": 12,
  "00000946": 12,
  "00000949": 12,
  "00000950": 12,
  "00000951": 12,
  "00000952": 12,
  "00000954": 12,
  "00000955": 12,
  "00000957": 12,
  "00000958": 12,
  "00000960": 12,
  "00000961": 12,
  "00000964": 12,
  "00000965": 12,
  "00000966": 12,
  "00000969": 12,
  "00000970": 12,
  "00000972": 12,
  "00000973": 12,
  "00000974": 12,
  "00000975": 12,
  "00000978": 12,
  "00000981": 12,
  "00000982": 12,
  "00000983": 12,
  "00000984": 12,
  "00000986": 12,
  "00000987": 12,
  "00000989": 12,
  "00000990": 12,
  "00000992": 12,
  "00000993": 14,
  "00000994": 16,
  "00000995": 14,
  "00000996": 14,
  "00000997": 16,
  "00000998": 20,
  "00000999": 20,
  "00001000": 14,
  "00001001": 16,
  "00001002": 16,
  "00001003": 20,
  "00001004": 14,
  "00001005": 12,
  "00001006": 18,
  "00001008": 12,
  "00001009": 14,
  "00001010": 16,
  "00001011": 14,
  "00001012": 14,
  "00001013": 16,
  "00001014": 20,
  "00001015": 20,
  "00001016": 14,
  "00001017": 16,
  "00001018": 16,
  "00001019": 20,
  "00001020": 14,
  "00001021": 12,
  "00001022": 18,
  "00001024": 12,
  "00001025": 12,
  "00001028": 12,
  "00001029": 12,
  "00001030": 12,
  "00001033": 12,
  "00001034": 12,
  "00001036": 12,
  "00001037": 12,
  "00001038": 12,
  "00001039": 12,
  "00001042": 12,
  "00001045": 12,
  "00001046": 12,
  "00001047": 12,
  "00001048": 12,
  "00001050": 12,
  "00001051": 12,
  "00001053": 12,
  "00001054": 12,
  "00001056": 12,
  "00001058": 14,
  "00001059": 20,
  "00001060": 14,
  "00001061": 16,
  "00001062": 14,
  "00001063": 20,
  "00001064": 12,
  "00001065": 20,
  "00001066": 16,
  "00001067": 14,
  "00001068": 16,
  "00001069": 14,
  "00001070": 16,
  "00001071": 14,
  "00001072": 12,
  "00001073": 14,
  "00001074": 16,
  "00001075": 20,
  "00001076": 14,
  "00001077": 12,
  "00001078": 20,
  "00001079": 16,
  "00001080": 14,
  "00001081": 12,
  "00001083": 20,
  "00001084": 16,
  "00001085": 14,
  "00001086": 14,
  "00001087": 14,
  "00001088": 16,
  "00001089": 14,
  "00001090": 16,
  "00001091": 16,
  "00001092": 14,
  "00001094": 12,
  "00001095": 20,
  "00001096": 14,
  "00001097": 16,
  "00001098": 20,
  "00001099": 12,
  "00001100": 14,
  "00001101": 16,
  "00001102": 20,
  "00001103": 14,
  "00001104": 14,
  "00001106": 12,
  "00001107": 12,
  "00001108": 12,
  "00001109": 12,
  "00001110": 12,
  "00001112": 12,
  "00001116": 12,
  "00001117": 12,
  "00001118": 12,
  "00001120": 12,
  "00001121": 12,
  "00001122": 12,
  "00001123": 12,
  "00001127": 12,
  "00001130": 12,
  "00001131": 12,
  "00001132": 12,
  "00001133": 12,
  "00001135": 12,
  "00001136": 12,
  "00001137": 12,
  "00001138": 14,
  "00001140": 14,
  "00001141": 14,
  "00001142": 12,
  "00001143": 20,
  "00001144": 16,
  "00001145": 20,
  "00001146": 16,
  "00001147": 14,
  "00001148": 14,
  "00001149": 18,
  "00001150": 16,
  "00001151": 14,
  "00001152": 14,
  "00001157": 12,
  "00001158": 12,
  "00001159": 12,
  "00001160": 12,
  "00001161": 12,
  "00001162": 12,
  "00001164": 12,
  "00001165": 12,
  "00001166": 12,
  "00001168": 12,
  "00001169": 16,
  "00001170": 18,
  "00001171": 14,
  "00001172": 20,
  "00001173": 16,
  "00001174": 14,
  "00001175": 14,
  "00001176": 12,
  "00001177": 14,
  "00001178": 18,
  "00001179": 12,
  "00001180": 16,
  "00001181": 14,
  "00001183": 14,
  "00001184": 14,
  "00001186": 12,
  "00001187": 12,
  "00001188": 12,
  "00001189": 12,
  "00001190": 12,
  "00001192": 12,
  "00001196": 12,
  "00001197": 12,
  "00001198": 12,
  "00001200": 12,
  "00001202": 12,
  "00001203": 12,
  "00001204": 12,
  "00001205": 12,
  "00001206": 12,
  "00001208": 12,
  "00001212": 12,
  "00001213": 12,
  "00001214": 12,
  "00001216": 12,
  "00001217": 16,
  "00001218": 14,
  "00001219": 14,
  "00001220": 14,
  "00001221": 16,
  "00001222": 14,
  "00001223": 12,
  "00001224": 20,
  "00001225": 14,
  "00001226": 18,
  "00001227": 14,
  "00001228": 12,
  "00001230": 16,
  "00001231": 14,
  "00001232": 14,
  "00001233": 12,
  "00001236": 12,
  "00001237": 12,
  "00001238": 12,
  "00001239": 12,
  "00001242": 12,
  "00001244": 12,
  "00001245": 12,
  "00001247": 12,
  "00001248": 12,
  "00001249": 12,
  "00001252": 12,
  "00001253": 12,
  "00001254": 12,
  "00001257": 12,
  "00001258": 12,
  "00001260": 12,
  "00001261": 12,
  "00001262": 12,
  "00001263": 12,
  "00001269": 12,
  "00001270": 12,
  "00001271": 12,
  "00001272": 12,
  "00001273": 12,
  "00001274": 12,
  "00001276": 12,
  "00001277": 12,
  "00001278": 12,
  "00001280": 12,
  "00001285": 12,
  "00001286": 12,
  "00001287": 12,
  "00001288": 12,
  "00001289": 12,
  "00001290": 12,
  "00001292": 12,
  "00001293": 12,
  "00001294": 12,
  "00001296": 12,
  "00001297": 12,
  "00001298": 12,
  "00001299": 12,
  "00001300": 12,
  "00001302": 12,
  "00001303": 12,
  "00001307": 12,
  "00001308": 12,
  "00001310": 12,
  "00001312": 12,
  "00001313": 12,
  "00001316": 12,
  "00001318": 12,
  "00001319": 12,
  "00001321": 12,
  "00001322": 12,
  "00001323": 12,
  "00001325": 12,
  "00001326": 12,
  "00001327": 12,
  "00001331": 12,
  "00001333": 12,
  "00001336": 12,
  "00001337": 12,
  "00001338": 12,
  "00001339": 12,
  "00001340": 12,
  "00001341": 12,
  "00001343": 12,
  "00001344": 12,
  "00001346": 12,
  "00001347": 12,
  "00001348": 12,
  "00001349": 12,
  "00001350": 12,
  "00001352": 12,
  "00001356": 12,
  "00001357": 12,
  "00001358": 12,
  "00001360": 12,
  "00001365": 12,
  "00001366": 12,
  "00001367": 12,
  "00001368": 12,
  "00001369": 12,
  "00001370": 12,
  "00001372": 12,
  "00001373": 12,
  "00001374": 12,
  "00001376": 12,
  "00001377": 12,
  "00001378": 12,
  "00001379": 12,
  "00001380": 12,
  "00001385": 12,
  "00001386": 12,
  "00001387": 12,
  "00001388": 12,
  "00001389": 12,
  "00001392": 12,
  "00001394": 12,
  "00001395": 12,
  "00001396": 12,
  "00001397": 12,
  "00001398": 12,
  "00001399": 12,
  "00001401": 12,
  "00001403": 12,
  "00001404": 12,
  "00001405": 12,
  "00001409": 12,
  "00001410": 12,
  "00001411": 12,
  "00001415": 12,
  "00001418": 12,
  "00001419": 12,
  "00001420": 12,
  "00001421": 12,
  "00001423": 12,
  "00001424": 12,
  "00001426": 12,
  "00001427": 12,
  "00001428": 12,
  "00001429": 12,
  "00001430": 12,
  "00001431": 12,
  "00001433": 12,
  "00001435": 12,
  "00001436": 12,
  "00001437": 12,
  "00001442": 12,
  "00001445": 12,
  "00001446": 12,
  "00001447": 12,
  "00001448": 12,
  "00001450": 12,
  "00001451": 12,
  "00001453": 12,
  "00001454": 12,
  "00001456": 12,
  "00001457": 12,
  "00001458": 12,
  "00001463": 12,
  "00001464": 12,
  "00001466": 12,
  "00001468": 12,
  "00001469": 12,
  "00001470": 12,
  "00001471": 12,
  "00001472": 12,
  "00001474": 12,
  "00001475": 12,
  "00001476": 12,
  "00001477": 14,
  "00001478": 12,
  "00001479": 12,
  "00001480": 12,
  "00001481": 16,
  "00001482": 12,
  "00001483": 14,
  "00001484": 14,
  "00001485": 12,
  "00001486": 14,
  "00001487": 12,
  "00001488": 12,
  "00001489": 12,
  "00001492": 12,
  "00001493": 12,
  "00001494": 12,
  "00001497": 12,
  "00001498": 12,
  "00001500": 12,
  "00001501": 12,
  "00001502": 12,
  "00001503": 12,
  "00001505": 12,
  "00001506": 12,
  "00001507": 12,
  "00001508": 16,
  "00001509": 14,
  "00001510": 12,
  "00001511": 12,
  "00001512": 12,
  "00001513": 14,
  "00001514": 12,
  "00001515": 12,
  "00001516": 14,
  "00001517": 12,
  "00001519": 12,
  "00001520": 12,
  "00001521": 12,
  "00001522": 12,
  "00001526": 12,
  "00001527": 12,
  "00001528": 12,
  "00001530": 12,
  "00001531": 12,
  "00001534": 12,
  "00001535": 12,
  "00001536": 12,
  "00001537": 12,
  "00001538": 12,
  "00001539": 14,
  "00001540": 12,
  "00001542": 12,
  "00001543": 12,
  "00001544": 12,
  "00001545": 14,
  "00001546": 16,
  "00001547": 12,
  "00001548": 12,
  "00001549": 12,
  "00001550": 12,
  "00001551": 12,
  "00001552": 12,
  "00001553": 12,
  "00001554": 12,
  "00001555": 12,
  "00001556": 12,
  "00001557": 12,
  "00001558": 12,
  "00001559": 12,
  "00001561": 14,
  "00001562": 12,
  "00001563": 12,
  "00001564": 12,
  "00001565": 16,
  "00001566": 12,
  "00001567": 12,
  "00001568": 14,
  "00001569": 12,
  "00001570": 12,
  "00001575": 12,
  "00001576": 12,
  "00001578": 12,
  "00001580": 12,
  "00001581": 12,
  "00001582": 12,
  "00001583": 12,
  "00001584": 12,
  "00001585": 12,
  "00001586": 12,
  "00001587": 12,
  "00001588": 12,
  "00001589": 14,
  "00001590": 12,
  "00001591": 12,
  "00001592": 16,
  "00001593": 12,
  "00001594": 12,
  "00001595": 12,
  "00001596": 12,
  "00001598": 12,
  "00001599": 12,
  "00001600": 12,
  "00001602": 12,
  "00001603": 12,
  "00001604": 12,
  "00001605": 12,
  "00001606": 12,
  "00001607": 12,
  "00001609": 12,
  "00001611": 12,
  "00001612": 12,
  "00001613": 12,
  "00001617": 12,
  "00001618": 12,
  "00001620": 12,
  "00001621": 12,
  "00001622": 12,
  "00001623": 12,
  "00001624": 12,
  "00001625": 14,
  "00001626": 12,
  "00001627": 12,
  "00001628": 12,
  "00001629": 12,
  "00001630": 14,
  "00001631": 12,
  "00001632": 12,
  "00001633": 12,
  "00001634": 12,
  "00001635": 14,
  "00001636": 12,
  "00001638": 12,
  "00001639": 12,
  "00001640": 12,
  "00001641": 12,
  "00001642": 14,
  "00001643": 12,
  "00001644": 12,
  "00001645": 12,
  "00001646": 12,
  "00001647": 12,
  "00001648": 12,
  "00001650": 12,
  "00001651": 12,
  "00001652": 12,
  "00001653": 12,
  "00001654": 12,
  "00001655": 12,
  "00001656": 12,
  "00001657": 14,
  "00001658": 12,
  "00001659": 12,
  "00001660": 14,
  "00001661": 12,
  "00001662": 12,
  "00001663": 12,
  "00001664": 12,
  "00001666": 12,
  "00001667": 12,
  "00001668": 12,
  "00001669": 12,
  "00001670": 12,
  "00001671": 12,
  "00001673": 12,
  "00001675": 12,
  "00001676": 12,
  "00001677": 12,
  "00001681": 12,
  "00001684": 12,
  "00001685": 12,
  "00001686": 12,
  "00001687": 12,
  "00001690": 12,
  "00001692": 12,
  "00001693": 12,
  "00001695": 12,
  "00001696": 12,
]
def genotype_gvcfs_input_amounts = [
  "00000242": 148,
  "00000243": 148,
  "00000244": 148,
  "00000245": 148,
  "00000246": 148,
  "00000247": 148,
  "00000248": 148,
  "00000249": 148,
  "00000250": 148,
  "00000251": 148,
  "00000262": 40,
  "00000294": 42,
  "00000314": 42,
  "00000321": 42,
  "00000415": 50,
  "00000474": 56,
  "00000501": 58,
  "00000538": 60,
  "00000557": 60,
  "00000589": 62,
  "00000597": 62,
  "00000638": 64,
  "00000702": 70,
  "00000734": 72,
  "00000751": 72,
  "00000766": 72,
  "00000783": 72,
  "00000810": 74,
  "00000837": 76,
  "00000906": 82,
  "00001007": 92,
  "00001023": 92,
  "00001057": 96,
  "00001082": 96,
  "00001093": 96,
  "00001139": 100,
  "00001182": 102,
  "00001229": 106,
  "00001473": 136,
  "00001518": 138,
  "00001541": 140,
  "00001560": 140,
  "00001597": 142,
  "00001619": 144,
  "00001637": 144,
  "00001649": 144,
]

file_inputs = jsonSlurper.parseText(file("${projectDir}/file_inputs.json").text)
alignment_to_reference_args = jsonSlurper.parseText(file("${projectDir}/alignment_to_reference_args.json").text)
sort_sam_args = jsonSlurper.parseText(file("${projectDir}/sort_sam_args.json").text)
dedup_args = jsonSlurper.parseText(file("${projectDir}/dedup_args.json").text)
add_replace_args = jsonSlurper.parseText(file("${projectDir}/add_replace_args.json").text)
realign_target_creator_args = jsonSlurper.parseText(file("${projectDir}/realign_target_creator_args.json").text)
indel_realign_args = jsonSlurper.parseText(file("${projectDir}/indel_realign_args.json").text)
haplotype_caller_args = jsonSlurper.parseText(file("${projectDir}/haplotype_caller_args.json").text)
merge_gcvf_args = jsonSlurper.parseText(file("${projectDir}/merge_gcvf_args.json").text)
genotype_gvcfs_args = jsonSlurper.parseText(file("${projectDir}/genotype_gvcfs_args.json").text)
combine_variants_args = jsonSlurper.parseText(file("${projectDir}/combine_variants_args.json").text)
select_variants_snp_args = jsonSlurper.parseText(file("${projectDir}/select_variants_snp_args.json").text)
filtering_snp_args = jsonSlurper.parseText(file("${projectDir}/filtering_snp_args.json").text)
select_variants_indel_args = jsonSlurper.parseText(file("${projectDir}/select_variants_indel_args.json").text)
filtering_indel_args = jsonSlurper.parseText(file("${projectDir}/filtering_indel_args.json").text)


process task_alignment_to_reference {
  cpus 1
  memory '1.95 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "alignment_to_reference_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py alignment_to_reference_${id} ${alignment_to_reference_args.get(id).get("resources")} --out "{${alignment_to_reference_args.get(id).get("out")}}" \$inputs
  """
}
process task_sort_sam {
  cpus 1
  memory '1.49 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "sort_sam_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py sort_sam_${id} ${sort_sam_args.get(id).get("resources")} --out "{${sort_sam_args.get(id).get("out")}}" \$inputs
  """
}
process task_dedup {
  cpus 1
  memory '2.08 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "dedup_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py dedup_${id} ${dedup_args.get(id).get("resources")} --out "{${dedup_args.get(id).get("out")}}" \$inputs
  """
}
process task_add_replace {
  cpus 1
  memory '1.71 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "add_replace_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py add_replace_${id} ${add_replace_args.get(id).get("resources")} --out "{${add_replace_args.get(id).get("out")}}" \$inputs
  """
}
process task_realign_target_creator {
  cpus 3
  memory '3.17 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "realign_target_creator_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py realign_target_creator_${id} ${realign_target_creator_args.get(id).get("resources")} --out "{${realign_target_creator_args.get(id).get("out")}}" \$inputs
  """
}
process task_indel_realign {
  cpus 1
  memory '2.10 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "indel_realign_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py indel_realign_${id} ${indel_realign_args.get(id).get("resources")} --out "{${indel_realign_args.get(id).get("out")}}" \$inputs
  """
}
process task_haplotype_caller {
  cpus 5
  memory '4.20 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "haplotype_caller_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py haplotype_caller_${id} ${haplotype_caller_args.get(id).get("resources")} --out "{${haplotype_caller_args.get(id).get("out")}}" \$inputs
  """
}
process task_merge_gcvf {
  cpus 30
  memory '18.16 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "merge_gcvf_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py merge_gcvf_${id} ${merge_gcvf_args.get(id).get("resources")} --out "{${merge_gcvf_args.get(id).get("out")}}" \$inputs
  """
}
process task_genotype_gvcfs {
  cpus 7
  memory '5.02 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "genotype_gvcfs_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py genotype_gvcfs_${id} ${genotype_gvcfs_args.get(id).get("resources")} --out "{${genotype_gvcfs_args.get(id).get("out")}}" \$inputs
  """
}
process task_combine_variants {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "combine_variants_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py combine_variants_${id} ${combine_variants_args.get(id).get("resources")} --out "{${combine_variants_args.get(id).get("out")}}" \$inputs
  """
}
process task_select_variants_snp {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "select_variants_snp_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py select_variants_snp_${id} ${select_variants_snp_args.get(id).get("resources")} --out "{${select_variants_snp_args.get(id).get("out")}}" \$inputs
  """
}
process task_filtering_snp {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "filtering_snp_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py filtering_snp_${id} ${filtering_snp_args.get(id).get("resources")} --out "{${filtering_snp_args.get(id).get("out")}}" \$inputs
  """
}
process task_select_variants_indel {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "select_variants_indel_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py select_variants_indel_${id} ${select_variants_indel_args.get(id).get("resources")} --out "{${select_variants_indel_args.get(id).get("out")}}" \$inputs
  """
}
process task_filtering_indel {
  cpus 1
  memory '1.26 GB'
  input:
    tuple val( id ), path( "*" )
  output:
    path( "filtering_indel_????????_outfile_????*" )
  script:
  """
  inputs=\$(find . -maxdepth 1 -name \"workflow_infile_*\" -or -name \"*_outfile_0*\")
  wfbench.py filtering_indel_${id} ${filtering_indel_args.get(id).get("resources")} --out "{${filtering_indel_args.get(id).get("out")}}" \$inputs
  """
}
workflow {
  workflow_inputs = Channel.fromPath("${params.indir}/*")

  alignment_to_reference_in = workflow_inputs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "alignment_to_reference")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 11)
  alignment_to_reference_out = task_alignment_to_reference(alignment_to_reference_in)

  concatenated_FOR_sort_sam = workflow_inputs.concat(alignment_to_reference_out)
  sort_sam_in = concatenated_FOR_sort_sam.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "sort_sam")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2)
  sort_sam_out = task_sort_sam(sort_sam_in)

  concatenated_FOR_dedup = workflow_inputs.concat(sort_sam_out)
  dedup_in = concatenated_FOR_dedup.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "dedup")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 3)
  dedup_out = task_dedup(dedup_in)

  concatenated_FOR_add_replace = workflow_inputs.concat(dedup_out)
  add_replace_in = concatenated_FOR_add_replace.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "add_replace")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 3)
  add_replace_out = task_add_replace(add_replace_in)

  concatenated_FOR_realign_target_creator = workflow_inputs.concat(add_replace_out)
  realign_target_creator_in = concatenated_FOR_realign_target_creator.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "realign_target_creator")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 12)
  realign_target_creator_out = task_realign_target_creator(realign_target_creator_in)

  concatenated_FOR_indel_realign = workflow_inputs.concat(add_replace_out, realign_target_creator_out)
  indel_realign_in = concatenated_FOR_indel_realign.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "indel_realign")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 13)
  indel_realign_out = task_indel_realign(indel_realign_in)

  concatenated_FOR_haplotype_caller = workflow_inputs.concat(indel_realign_out)
  haplotype_caller_in = concatenated_FOR_haplotype_caller.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "haplotype_caller")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.map { id, file -> tuple( groupKey(id, haplotype_caller_input_amounts[id]), file ) }
  .groupTuple()
  haplotype_caller_out = task_haplotype_caller(haplotype_caller_in)

  concatenated_FOR_merge_gcvf = workflow_inputs.concat(haplotype_caller_out)
  merge_gcvf_in = concatenated_FOR_merge_gcvf.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "merge_gcvf")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 2471)
  merge_gcvf_out = task_merge_gcvf(merge_gcvf_in)

  concatenated_FOR_genotype_gvcfs = workflow_inputs.concat(haplotype_caller_out)
  genotype_gvcfs_in = concatenated_FOR_genotype_gvcfs.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "genotype_gvcfs")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.map { id, file -> tuple( groupKey(id, genotype_gvcfs_input_amounts[id]), file ) }
  .groupTuple()
  genotype_gvcfs_out = task_genotype_gvcfs(genotype_gvcfs_in)

  concatenated_FOR_combine_variants = workflow_inputs.concat(genotype_gvcfs_out)
  combine_variants_in = concatenated_FOR_combine_variants.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "combine_variants")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 102)
  combine_variants_out = task_combine_variants(combine_variants_in)

  concatenated_FOR_select_variants_snp = workflow_inputs.concat(combine_variants_out)
  select_variants_snp_in = concatenated_FOR_select_variants_snp.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "select_variants_snp")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 12)
  select_variants_snp_out = task_select_variants_snp(select_variants_snp_in)

  concatenated_FOR_filtering_snp = workflow_inputs.concat(select_variants_snp_out)
  filtering_snp_in = concatenated_FOR_filtering_snp.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "filtering_snp")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 11)
  filtering_snp_out = task_filtering_snp(filtering_snp_in)

  concatenated_FOR_select_variants_indel = workflow_inputs.concat(combine_variants_out)
  select_variants_indel_in = concatenated_FOR_select_variants_indel.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "select_variants_indel")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 12)
  select_variants_indel_out = task_select_variants_indel(select_variants_indel_in)

  concatenated_FOR_filtering_indel = workflow_inputs.concat(select_variants_indel_out)
  filtering_indel_in = concatenated_FOR_filtering_indel.flatten().flatMap{
    List<String> ids = extractTaskIDforFile(it, "filtering_indel")
    def pairs = new ArrayList()
    for (id : ids) pairs.add([id, it])
    return pairs
  }.groupTuple(size: 11)
  filtering_indel_out = task_filtering_indel(filtering_indel_in)

  println("Workflow Synthetic_Soykb finished successfully.")
}
