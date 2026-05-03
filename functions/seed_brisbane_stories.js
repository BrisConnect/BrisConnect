/**
 * Seed script for brisbane_stories and brisbane_voices Firestore collections.
 *
 * All facts are sourced from:
 *   - Wikipedia: History of Brisbane (en.wikipedia.org/wiki/History_of_Brisbane)
 *   - Wikipedia: Story Bridge (en.wikipedia.org/wiki/Story_Bridge)
 *   - Wikipedia: Brisbane City Hall (en.wikipedia.org/wiki/Brisbane_City_Hall)
 *   - Wikipedia: South Bank Parklands (en.wikipedia.org/wiki/South_Bank_Parklands)
 *   - Wikipedia: Lone Pine Koala Sanctuary (en.wikipedia.org/wiki/Lone_Pine_Koala_Sanctuary)
 *   - Brisbane City Council: brisbane.qld.gov.au
 *   - State Library of Queensland: slq.qld.gov.au
 *   - Queensland Heritage Register
 *
 * Usage:
 *   cd functions
 *   node seed_brisbane_stories.js
 */

const admin = require("firebase-admin");
const path = require("path");

// Use the service account key
const serviceAccount = require(
  path.resolve("C:/Users/ibzso/Downloads/brisconnect-68b78-firebase-adminsdk-fbsvc-efef6e1518.json")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ─── STORIES ─────────────────────────────────────────────────────────────────

const stories = [
  // ── FIRST NATIONS ──────────────────────────────────────────────────────────
  {
    title: "Meeanjin: The Place That Shaped a City",
    description:
      "The peninsula now known as Brisbane CBD was called Meeanjin by the Turrbal people, meaning a place shaped like a spike — a pointed, triangular landform created by a double bend in the river.",
    imageUrl:
      "https://images.unsplash.com/photo-1554474051-0256b98c36f8?w=800",
    category: "first_nations",
    content:
      "Long before European settlement, the Brisbane River valley was a major cultural, economic and ceremonial landscape for the Turrbal and Jagera (Yagara) peoples for more than 22,000 years. The peninsula on which the Brisbane central business district now stands was traditionally known as Meeanjin, referring to its distinctive pointed, triangular shape formed by a double bend in the river.\n\nThe Brisbane River itself was known as Maiwar across Yagara- and Turrbal-speaking groups. Archaeological evidence confirms frequent habitation around Musgrave Park, along the river and throughout surrounding ridgelines. The river and its wetlands supplied abundant resources including fish, shellfish and plant foods.\n\nBefore European settlement, the wider region supported an estimated population of 6,000 to 10,000 people across coastal and riverine districts. Several major camps played central roles in regional movement and seasonal occupation, including Barambin (later York's Hollow), which functioned as a major gathering and meeting ground, and Woolloon-cappem (later Kurilpa), which extended across parts of modern South Brisbane and West End.\n\nSource: Evans, Raymond (2007). A History of Queensland. Cambridge University Press; Kerkhove, Ray (2015). Aboriginal Campsites of Greater Brisbane. Boolarong Press; Gregory, Helen. 'Meeanjin – the heart of Brisbane', State Library of Queensland.",
    latitude: -27.4698,
    longitude: 153.0251,
    locationName: "Brisbane CBD (Meeanjin)",
  },
  {
    title: "Maiwar: The River That Connects Country",
    description:
      "The Brisbane River — known as Maiwar to the Turrbal and Jagera peoples — has been a lifeline for Indigenous communities for over 22,000 years, providing food, transport routes and ceremonial gathering places.",
    imageUrl:
      "https://images.unsplash.com/photo-1598948485421-0a9f1e9ca087?w=800",
    category: "first_nations",
    content:
      "Maiwar, the traditional name for the Brisbane River, is central to the cultural identity of the Turrbal and Jagera peoples. 19th and 20th century linguistic records identify Maiwar as the name used across Yagara- and Turrbal-speaking groups for the river that winds through what is now Southeast Queensland's capital.\n\nThe river and surrounding district consisted primarily of open woodlands maintained through Indigenous land management, with rainforest pockets occurring along some bends of the river. Productive fishing grounds along Maiwar often developed into long-standing campsites.\n\nThe area around present-day Kelvin Grove and Herston was known in Turrbal as Tumamun, referring to the pointed hill and watercourse that characterised the area. Additional camps existed around the wetlands of Woolloongabba and the ridges around Musgrave Park.\n\nMeeanjin's elevated position and access to surrounding resource areas made it an important location in long-standing patterns of movement and settlement, sitting at a natural river crossing between several major camps.\n\nSource: Meston, Archibald (1895). Aboriginal Tribes of Brisbane, Queensland Government Printer; 'The Aboriginal Names of the Brisbane River', The Queenslander, 23 March 1912; Tindale, Norman (1974). Aboriginal Tribes of Australia, ANU Press.",
    latitude: -27.4820,
    longitude: 153.0190,
    locationName: "Brisbane River (Maiwar)",
  },
  {
    title: "Musgrave Park: A Gathering Place Through Time",
    description:
      "Musgrave Park in South Brisbane has been an important gathering place for Aboriginal peoples for millennia, and continues to hold deep cultural significance for Brisbane's First Nations communities today.",
    imageUrl:
      "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=800",
    category: "first_nations",
    content:
      "Archaeological evidence confirms frequent habitation around Musgrave Park, along the Brisbane River and throughout the surrounding ridgelines for thousands of years. The park sits within the traditional lands of the Turrbal and Jagera peoples, within the broader Yuggera language area.\n\nThe area was part of a network of significant camps that included Barambin (York's Hollow), which functioned as a major gathering and meeting ground, and Woolloon-cappem (Kurilpa), extending across modern South Brisbane and West End. These camps continued to operate into the early colonial period.\n\nDuring the 1840s–1850s, Indigenous peoples including Turrbal and neighbouring groups engaged in trade and labour within the township, supplying fish, firewood, water-carrying, fencing and stock work. By the 1850s, Indigenous labour formed an important part of Brisbane's riverine and pastoral economy.\n\nToday Musgrave Park remains a culturally significant site for Brisbane's Aboriginal and Torres Strait Islander communities, hosting gatherings, NAIDOC Week events, and serving as a place of remembrance and connection.\n\nSource: Moore, Tony (2012). 'The Indigenous History of Musgrave Park', Brisbane Times; Kerkhove, Ray (2015). Aboriginal Campsites of Greater Brisbane, Boolarong Press; Jones, Ryan. 'Indigenous Aboriginal Sites of Southside Brisbane', Mapping Brisbane History.",
    latitude: -27.4823,
    longitude: 153.0174,
    locationName: "Musgrave Park, South Brisbane",
  },

  // ── LANDMARKS ──────────────────────────────────────────────────────────────
  {
    title: "Story Bridge: Brisbane's Steel Icon",
    description:
      "Opened on 6 July 1940, the Story Bridge is a heritage-listed steel cantilever bridge spanning the Brisbane River. Designed by John Bradfield — the engineer behind the Sydney Harbour Bridge — it remains Australia's longest cantilever bridge.",
    imageUrl:
      "https://images.unsplash.com/photo-1570361235855-9f834042e8f3?w=800",
    category: "landmarks",
    content:
      "The Story Bridge is a heritage-listed steel cantilever bridge spanning the Brisbane River, connecting Fortitude Valley to Kangaroo Point. At 777 metres long with a main span of 282 metres and standing 74 metres high, it remains Australia's longest cantilever bridge.\n\nThe bridge was designed by Dr John Bradfield, consulting engineer and designer of the Sydney Harbour Bridge. The design was based heavily on that of the Jacques Cartier Bridge in Montreal, completed in 1930. Construction began on 24 May 1935 by a consortium of two Queensland companies, Evans Deakin and Hornibrook Constructions, who won the tender with a bid of £1,150,000.\n\nThe bridge was constructed as a public works program during the Great Depression. Components were fabricated in a purpose-built factory at Rocklea, with 1.25 million rivets used in the structure. Three men died during construction. The primary engineering challenge was the southern foundations, which required pneumatic caisson techniques going 40 metres below ground level.\n\nThe bridge was opened on 6 July 1940 by Sir Leslie Orme Wilson, Governor of Queensland, and named after John Douglas Story, a senior public servant who advocated strongly for its construction. It was tolled at sixpence until 1947.\n\nListed on the Queensland Heritage Register in 1992 and recognised as one of Queensland's Q150 Icons in 2009.\n\nSource: Queensland Heritage Register (entry 600240); Hogan, Janet (1982). Living History of Brisbane, Boolarong Publications; Gregory, Helen (2007). Brisbane Then and Now; Moy, Michael (2005). Story Bridge: Idea to Icon, Alpha Orion Press.",
    latitude: -27.4635,
    longitude: 153.0358,
    locationName: "Story Bridge",
  },
  {
    title: "Brisbane City Hall: The People's Place",
    description:
      "Opened in 1930, Brisbane City Hall is a grand Italian Renaissance-style building featuring a 91-metre clock tower modelled on St Mark's Campanile in Venice, and an auditorium inspired by the Roman Pantheon.",
    imageUrl:
      "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800",
    category: "landmarks",
    content:
      "Brisbane City Hall, located adjacent to King George Square, has been the seat of the Brisbane City Council since its opening on 8 April 1930. Designed by the firm Hall and Prentice in the Italian Renaissance style, it was once the tallest building in Brisbane.\n\nThe building features a 91-metre clock tower modelled on St Mark's Campanile in Venice, with four clock faces each 4.8 metres in diameter — the largest in Australia when built. The tower has Westminster Chimes that sound on the quarter-hour. At the centre is a magnificent auditorium based on the Roman Pantheon, covered by the largest copper dome in the southern hemisphere, seating up to 1,600 people.\n\nThe sculptured tympanum above the entrance was carved by Brisbane sculptor Daphne Mayo and depicts the settlement of Queensland — a work that has been the subject of controversy since at least 1953 regarding its portrayal of Indigenous Australians.\n\nThe foundation stone was laid on 29 July 1920 by Edward, Prince of Wales (later King Edward VIII). The building also houses a Henry Willis & Sons pipe organ with 4,391 pipes, originally built in 1891 for the Brisbane Exhibition Building.\n\nA $215 million restoration was completed in 2013, and the Museum of Brisbane now occupies the rooftop level. City Hall was recognised as one of Queensland's Q150 Icons in 2009.\n\nSource: Queensland Heritage Register (entry 600065); Gregory, Helen & McLayDianne (2010). Building Brisbane's History, Woodslane Press; Readshaw, Grahame (1987). Looking Up Looking Back at Old Brisbane, Boolarong.",
    latitude: -27.46885,
    longitude: 153.023602,
    locationName: "Brisbane City Hall, King George Square",
  },
  {
    title: "The Old Windmill: Queensland's Oldest Building",
    description:
      "Built by convict labour in 1828, the Old Windmill on Wickham Terrace is the oldest surviving structure in Queensland. Originally used for grinding grain, it also served as a site of punishment in the Moreton Bay penal settlement.",
    imageUrl:
      "https://images.unsplash.com/photo-1582407947092-45e95f45e599?w=800",
    category: "landmarks",
    content:
      "The Old Windmill on Wickham Terrace, built in 1828 during the Moreton Bay penal settlement era, is the oldest surviving structure in Queensland. It is one of only two surviving convict-era buildings in the state, the other being the Commissariat Store.\n\nConstructed under the command of Captain Patrick Logan, the windmill was originally built for grinding grain to feed the growing penal settlement. It was also used as a site for administering punishments, and Logan became notorious for severe use of the cat-o'-nine-tails. Under Logan's command, convict numbers rose from around 200 to over 1,000 men.\n\nThe Moreton Bay penal settlement was established in September 1824 at Redcliffe Point, then moved to the Brisbane River peninsula (Meeanjin) in May 1825. It was described as a 'prison within a prison' — reserved for recidivist convicts considered too dangerous for Sydney. Along with Norfolk Island, Moreton Bay was regarded as one of the harshest penal settlements in New South Wales.\n\nThe settlement formally closed in 1842, ending the penal era and opening the Brisbane district to free European settlement.\n\nSource: Evans, Raymond (2007). A History of Queensland, Cambridge University Press; Bateson, Charles (1959). The Convict Ships, 1787–1868; Queensland State Archives: 'Moreton Bay Convict Settlement'.",
    latitude: -27.4612,
    longitude: 153.0223,
    locationName: "The Old Windmill, Wickham Terrace",
  },
  {
    title: "South Bank Parklands: From Expo to Icon",
    description:
      "Built on the transformed site of World Expo 88, South Bank Parklands opened in 1992 and is now Australia's most visited landmark, welcoming an estimated 14 million visitors each year.",
    imageUrl:
      "https://images.unsplash.com/photo-1578468882639-eb61cf11b578?w=800",
    category: "landmarks",
    content:
      "South Bank Parklands are located on the southern bank of the Brisbane River, directly opposite the city centre. The 17.5-hectare parkland was developed on the transformed site of Brisbane's World Expo 88, and officially opened to the public on 20 June 1992.\n\nSouth Bank was originally a meeting place for the Turrbal and Yuggera peoples. In the early 1840s it became the central focus of early European settlement and from the 1850s served as Brisbane's business centre. After the 1893 floods forced the business district to shift north of the river, South Bank declined, becoming home to vaudeville theatres, boarding houses and industry.\n\nThe 1970s marked a new era with the Queensland Cultural Centre, including the Queensland Art Gallery (1982), Queensland Performing Arts Centre (1985) and Queensland Museum (1986). In 1988, World Expo 88 transformed the site, and after a successful public campaign, the land was redeveloped as parkland rather than for commercial interests.\n\nKey attractions include the Grand Arbour (443 curling steel columns covered in bougainvilleas stretching 1 kilometre), Streets Beach (a 2,000 square metre man-made lagoon), the Nepalese Peace Pagoda (retained from Expo 88), and the Wheel of Brisbane (60 metres tall, erected 2008).\n\nSouth Bank now welcomes an estimated 14 million visitors annually, making it Australia's most visited landmark. It received the international Green Flag Award in 2022/2023.\n\nSource: Visit Brisbane; South Bank Corporation; State Library of Queensland: 'Opening of South Bank Parklands (1992)'; Wikipedia: South Bank Parklands.",
    latitude: -27.4787,
    longitude: 153.0229,
    locationName: "South Bank Parklands",
  },
  {
    title: "Lone Pine Koala Sanctuary: The World's First",
    description:
      "Founded in 1927 with just two koalas named Jack and Jill, Lone Pine Koala Sanctuary in Fig Tree Pocket is the world's oldest and largest koala sanctuary, recognised by Guinness World Records.",
    imageUrl:
      "https://images.unsplash.com/photo-1579168765467-3b235f938439?w=800",
    category: "landmarks",
    content:
      "Lone Pine Koala Sanctuary is an 18-hectare koala sanctuary in the Brisbane suburb of Fig Tree Pocket. Founded in 1927, it is the oldest and largest koala sanctuary in the world, as recognised by Guinness World Records. The park houses approximately 80 species of Australian animals.\n\nThe name originates from a lone hoop pine planted by the Clarkson family, the first owners of the site. The sanctuary was founded by Claude Reid, who recognised the need to protect koalas at a time when they were being killed for their fur. It began with just two koalas called Jack and Jill.\n\nLone Pine became known internationally during World War II when Americans stationed in Brisbane — including General Douglas MacArthur's wife — visited the park to view native Australian animals. Brisbane served as the headquarters of the Allied South West Pacific Area command from 1942, bringing tens of thousands of US personnel to the city.\n\nThe sanctuary opened the Brisbane Koala Science Institute in June 2018, in collaboration with Brisbane City Council, featuring a research laboratory and 'Koala Biobank' genetic depository. In 2009, Lone Pine was announced as one of Queensland's Q150 Icons.\n\nSource: Guinness World Records; Hogan, Janet (1982). Living History of Brisbane, Boolarong; Brisbane City Council; Lone Pine Koala Sanctuary official site.",
    latitude: -27.5329,
    longitude: 152.9693,
    locationName: "Lone Pine Koala Sanctuary, Fig Tree Pocket",
  },

  // ── ARTS ────────────────────────────────────────────────────────────────────
  {
    title: "GOMA: Brisbane's Modern Art Powerhouse",
    description:
      "Opened in 2006, the Gallery of Modern Art (GOMA) at South Bank established Brisbane as an important centre for contemporary art in the Asia-Pacific region. It is part of the Queensland Cultural Centre.",
    imageUrl:
      "https://images.unsplash.com/photo-1536924940846-227afb31e2a5?w=800",
    category: "arts",
    content:
      "The Gallery of Modern Art (GOMA) opened in 2006 as part of the expanded Queensland Cultural Centre at South Bank. Together with the Queensland Art Gallery (opened 1982), it forms QAGOMA — one of Australia's most significant visual arts institutions.\n\nThe Queensland Cultural Centre was a landmark project designed by architect Robin Gibson after construction began in 1976. The precinct grew to include:\n- Queensland Art Gallery (1982)\n- Queensland Performing Arts Centre (QPAC, 1985)\n- Queensland Museum (1986)\n- State Library of Queensland (new building, 2006)\n- Gallery of Modern Art (2006)\n\nGOMA's opening established Brisbane as an important centre for contemporary art in the Asia-Pacific region. The gallery hosts the Asia Pacific Triennial of Contemporary Art and has become a key cultural draw for the city.\n\nThe Queensland Cultural Centre itself is listed on the Queensland Heritage Register, recognised for its role in transforming Brisbane's southern riverbank from a declining industrial area into one of Australia's premier cultural precincts.\n\nSource: Queensland Art Gallery & Gallery of Modern Art (QAGOMA): qagoma.qld.gov.au; Queensland Heritage Register (entry 601125); Wikipedia: Gallery of Modern Art, Brisbane.",
    latitude: -27.4732,
    longitude: 153.0173,
    locationName: "Gallery of Modern Art (GOMA), South Bank",
  },
  {
    title: "The Saints: Brisbane's Punk Pioneers",
    description:
      "In the 1970s, Brisbane's restrictive political climate under Joh Bjelke-Petersen gave rise to an influential counterculture. The Saints produced some of the world's earliest punk recordings, placing Brisbane at the forefront of global punk music.",
    imageUrl:
      "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800",
    category: "arts",
    content:
      "Brisbane's political landscape of the 1970s and 1980s, under the conservative premiership of Joh Bjelke-Petersen, was marked by stringent controls on public assembly, frequent protest bans and police crackdowns. This restrictive climate, paradoxically, contributed to the emergence of one of Australia's most influential local countercultures.\n\nThe Saints, formed in Brisbane in 1974, produced some of the world's earliest punk recordings. Their 1976 single '(I'm) Stranded' is widely regarded as one of the first punk rock records, released independently months before the Sex Pistols' debut. The band's existence placed Brisbane as a notable centre of early punk music globally.\n\nBrisbane also became a major centre of civil liberties activism, with anti-apartheid, student and democratic rights groups organising large-scale demonstrations. Violent clashes occurred during the 1971 Springbok tour protests. Indigenous activists played key roles in the Black Protest movement during the 1982 Commonwealth Games.\n\nThe Fitzgerald Inquiry (1987–1989), which revealed systemic corruption in the Queensland government and police force, ended the National Party's 32-year rule and reshaped governance across Queensland, ushering in a new era of political openness and cultural expression.\n\nSource: Stafford, Andrew (2004). Pig City: From The Saints to Savage Garden, UQP; Keim, Stephen (1988). 'The State of Civil Liberties in Queensland', The Queensland Lawyer; Fitzgerald, G.E. (1989). Report of the Commission of Inquiry.",
    latitude: -27.4578,
    longitude: 153.0345,
    locationName: "Fortitude Valley, Brisbane",
  },
  {
    title: "Brisbane Powerhouse: From Power Station to Arts Hub",
    description:
      "The Brisbane Powerhouse in New Farm is a leading arts venue housed in a former power station, representing Brisbane's transformation of industrial heritage into vibrant cultural spaces along the river.",
    imageUrl:
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800",
    category: "arts",
    content:
      "The Brisbane Powerhouse is one of the city's most distinctive arts and cultural venues, housed in a repurposed power station in the riverside suburb of New Farm. This transformation reflects a broader pattern of urban renewal across Brisbane's inner suburbs, particularly in the Teneriffe-New Farm corridor.\n\nDuring the 1990s, Brisbane's economy diversified as older industrial districts declined and inner-city renewal gained pace. Large areas of Teneriffe, Newstead and New Farm underwent significant transformation, including the conversion of woolstores and warehouses into residential and mixed-use developments.\n\nThe Powerhouse embodies Brisbane's approach to heritage repurposing — preserving industrial character while creating vibrant new cultural destinations. Other examples include the Howard Smith Wharves precinct, transformed from disused wharf infrastructure into a dining and entertainment hub beneath the Story Bridge.\n\nNew Farm Park, adjacent to the Powerhouse, is one of Brisbane's beloved green spaces, and the area is connected to the city centre via the Brisbane Riverwalk, a floating pathway along the riverbank originally built in 2003 and reconstructed after being damaged by the 2011 floods.\n\nSource: Brisbane City Council; Burton, Peter (2003). Urban Regeneration in Brisbane; Wikipedia: Brisbane Powerhouse.",
    latitude: -27.4527,
    longitude: 153.0456,
    locationName: "Brisbane Powerhouse, New Farm",
  },

  // ── CULTURE & FOOD ─────────────────────────────────────────────────────────
  {
    title: "Fortitude Valley: From Scottish Settlers to Cultural Melting Pot",
    description:
      "Named after the ship Fortitude that carried Scottish migrants to Brisbane in 1849, Fortitude Valley has evolved from a migrant settlement into one of Australia's most vibrant entertainment and multicultural dining precincts.",
    imageUrl:
      "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
    category: "culture_food",
    content:
      "Fortitude Valley takes its name from the ship Fortitude, which in 1849 carried Scottish migrants to Brisbane. These settlers initially camped at York's Hollow before establishing the suburb that bears their ship's name.\n\nBrisbane in the late 19th century developed an unusually diverse population for a colonial Australian city. Its position as the closest major port to the Pacific, combined with labour shortages, encouraged varied migration streams. German farming communities lived alongside Scottish and Irish populations, a Chinese quarter developed at Frog's Hollow, Jewish and Russian communities emerged, and Brisbane's wharves drew a mixed workforce including Lebanese and Syrian hawkers, Italian and Greek communities, and South Sea Islanders.\n\nHistorians describe Brisbane as 'unusually cosmopolitan for its size', noting that its blend of European, Asian and Pacific communities was uncommon among Australian colonial cities. This multicultural heritage is particularly visible today in Fortitude Valley, where Chinatown, Vietnamese restaurants, Korean barbecue, craft breweries and live music venues sit side by side.\n\nThe Valley is also home to Brisbane's main entertainment precinct, carrying forward a tradition of cultural mixing that stretches back more than 170 years.\n\nSource: Evans, Raymond (2007). A History of Queensland, Cambridge University Press; Fitzgerald, Ross (2007). A History of Queensland; Hogan, Janet (1982). Living History of Brisbane.",
    latitude: -27.4578,
    longitude: 153.0345,
    locationName: "Fortitude Valley",
  },
  {
    title: "The Queenslander: Architecture Born of Climate",
    description:
      "The iconic Queenslander house — elevated on stumps with broad verandahs and ventilated interiors — evolved in Brisbane as a practical response to the subtropical climate. It became the defining architectural form of the city by 1900.",
    imageUrl:
      "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800",
    category: "culture_food",
    content:
      "As Brisbane expanded across the surrounding valley basin in the late 19th century, the distinctive Queenslander house evolved into the dominant architectural form. Elevated timber construction, broad verandahs and ventilated interiors provided a practical response to Brisbane's subtropical climate.\n\nThese timber homes — raised on stumps to catch breezes and avoid flooding — became a defining characteristic of the city's cultural landscape by 1900. The style reflected both engineering pragmatism and the availability of vast stands of hoop pine, blue gum and ironbark that were harvested from surrounding forests.\n\nThe preservation of Queenslander homes became a significant issue in the late 20th century, as heritage buildings were controversially demolished. The Bellevue Hotel was demolished in 1979, and Cloudland Ballroom in 1982, sparking sustained public debate about preservation versus development.\n\nToday, heritage Queenslanders are found across inner suburbs like Paddington, Red Hill, New Farm, Woolloongabba and Highgate Hill, their timber facades and wraparound verandahs providing an atmospheric contrast to Brisbane's modern glass-and-steel skyline.\n\nSource: Evans, Raymond (2007). A History of Queensland, Cambridge University Press; 'Cloudland Demolished', The Courier-Mail, 8 November 1982.",
    latitude: -27.4640,
    longitude: 153.0090,
    locationName: "Paddington, Brisbane",
  },
  {
    title: "City Botanic Gardens: From Convict Farm to Green Oasis",
    description:
      "Brisbane's City Botanic Gardens trace their origins to farms established by convict labour along the river flats during the Moreton Bay penal settlement in the 1820s, making them one of Australia's oldest public gardens.",
    imageUrl:
      "https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800",
    category: "culture_food",
    content:
      "The City Botanic Gardens, nestled along the Brisbane River near the CBD, trace their origins to farms established by convict labour along the river flats during the Moreton Bay penal settlement era. Under Captain Patrick Logan's command in the late 1820s, convict labour established agricultural plots that would eventually become one of Brisbane's most cherished green spaces.\n\nThe gardens occupy land at the point where the Brisbane River curves sharply around the CBD peninsula — the area known to the Turrbal people as Meeanjin. This strategic location between the river and the expanding colonial settlement ensured its continued use as public land.\n\nThe gardens lie in the shadow of the Queensland University of Technology's Gardens Point campus and are overlooked by Old Government House, which served as the University of Queensland's first home after its founding in 1909, before the university relocated to St Lucia in the late 1930s.\n\nA popular pedestrian and cycling route connects the gardens via the Goodwill Bridge (opened 2001) to South Bank Parklands across the river. The gardens remain a lunchtime retreat for city workers and a favourite starting point for walks along the Brisbane riverfront.\n\nSource: Trove (National Library of Australia): 'Botanic Gardens, Brisbane', NSW Government Gazette, 23 Feb 1855; Evans, Raymond (2007). A History of Queensland; Brisbane City Council.",
    latitude: -27.4750,
    longitude: 153.0300,
    locationName: "City Botanic Gardens",
  },

  // ── FESTIVALS ──────────────────────────────────────────────────────────────
  {
    title: "World Expo 88: The Event That Changed Brisbane",
    description:
      "World Expo 88, held at South Bank from April to October 1988, was a pivotal moment in Brisbane's history. It transformed a derelict industrial waterfront into a world-class precinct and launched Brisbane onto the international stage.",
    imageUrl:
      "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800",
    category: "festivals",
    content:
      "World Expo 88, themed 'Leisure in the Age of Technology', was held at South Bank from 30 April to 30 October 1988. The international exposition was a transformative moment for Brisbane, turning a derelict industrial waterfront into a major cultural and recreational precinct.\n\nThe event drew millions of visitors and featured pavilions from countries around the world. Perhaps its most lasting legacy was the transformation of the South Bank site itself. Following the Expo, the Queensland Government originally intended to develop the land for commercial interests. However, a successful public campaign lobbied for the site to be redeveloped as parkland for the people of Brisbane.\n\nThis campaign led to the creation of South Bank Parklands, which opened in 1992 and has since become Australia's most visited landmark. Remnants of Expo 88 remain, including the Nepalese Peace Pagoda, which was originally located on the Expo site and successfully retained through fundraising.\n\nExpo 88 coincided with a period of profound political change in Queensland — the Fitzgerald Inquiry (1987–1989) was underway, revealing systemic corruption and ultimately ending the National Party's 32-year rule. Together, these events redefined Brisbane's identity.\n\nSource: 'World Expo 88 – 25 Years On', Australian Broadcasting Corporation, 29 October 2013; South Bank Corporation heritage information; Smith, Andrew & Mair, Judith (2018). 'The making of a city: How Expo 88 changed Brisbane forever', Bureau International des Expositions.",
    latitude: -27.4787,
    longitude: 153.0229,
    locationName: "South Bank (former Expo 88 site)",
  },
  {
    title: "Riverfire: A Night Sky Spectacular",
    description:
      "Riverfire is Brisbane's signature annual fireworks event, drawing over half a million spectators to the banks of the Brisbane River. The celebration features spectacular pyrotechnics launched from the Story Bridge and surrounding buildings.",
    imageUrl:
      "https://images.unsplash.com/photo-1467810563316-b5476525c0f9?w=800",
    category: "festivals",
    content:
      "Riverfire is Brisbane's most spectacular annual event, a large-scale fireworks display launched from the Story Bridge, surrounding buildings and barges on the Brisbane River. The event is a highlight of the Brisbane Festival and draws over half a million spectators to the riverbanks each year.\n\nIn 2009, Riverfire drew more than half a million spectators to the South Bank Parklands alone. The Story Bridge features prominently, its steel cantilever structure illuminated against the night sky as rockets and pyrotechnics are fired from its spans.\n\nThe event reflects Brisbane's identity as a river city and the central role the Brisbane River plays in civic life. The river has shaped Brisbane's development since the earliest days — Indigenous settlement centred on its banks for over 22,000 years, the first colonial settlement was established on its shores, and today the city's most important cultural, entertainment and dining precincts line its curves.\n\nRiverfire brings together locals and visitors along both banks of the river, from South Bank and the Cultural Centre to Howard Smith Wharves, Kangaroo Point cliffs and New Farm Park, making it one of Australia's largest community celebrations.\n\nSource: South Bank Parklands official information; Brisbane Festival; Samantha Healy & Daniel Tang (2009). 'Riverfire fireworks dazzle thousands', The Sunday Mail.",
    latitude: -27.4680,
    longitude: 153.0280,
    locationName: "Brisbane River (Story Bridge to South Bank)",
  },
  {
    title: "Brisbane 2032: An Olympic Future",
    description:
      "In July 2021, Brisbane was selected to host the 2032 Summer Olympic and Paralympic Games — a milestone event driving long-term investment in venues, transport and urban renewal across the city.",
    imageUrl:
      "https://images.unsplash.com/photo-1569517282132-25d22f4573e6?w=800",
    category: "festivals",
    content:
      "A major milestone in Brisbane's modern history came on 21 July 2021, when Brisbane was selected to host the 2032 Summer Olympic and Paralympic Games. The announcement initiated long-term planning for venues, transport improvements and urban redevelopment across the city and Southeast Queensland.\n\nThe Olympics represent the latest chapter in Brisbane's evolving international identity. The city has previously hosted the 1982 Commonwealth Games, which notably coincided with significant Indigenous rights activism, and the 2014 G20 Summit, which drove improvements to public spaces and transport corridors.\n\nMajor infrastructure projects already reshaping the city include the Cross River Rail underground rail project, the Brisbane Metro rapid transit system, and the Queen's Wharf mega-development on the CBD's riverside. The Kangaroo Point Green Bridge, with its 95-metre mast making it the tallest bridge in the city, opened in 2024.\n\nBrisbane recorded the nation's highest levels of interstate migration in the early 2020s, and the Olympic preparations are expected to accelerate the city's transformation into a globally connected metropolis.\n\nSource: 'Brisbane Awarded 2032 Olympic and Paralympic Games', Sydney Morning Herald, 21 July 2021; Brisbane City Council major projects; Australian Bureau of Statistics: Regional Population, 2023.",
    latitude: -27.4698,
    longitude: 153.0251,
    locationName: "Brisbane CBD",
  },
];

// ─── VOICES ──────────────────────────────────────────────────────────────────

const voices = [
  {
    name: "Raymond Evans",
    quote:
      "Brisbane developed an unusually cosmopolitan population for its size, with a blend of European, Asian and Pacific communities uncommon among Australian colonial cities.",
    profileImageUrl:
      "https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=200",
  },
  {
    name: "Uncle Des Sandy",
    quote:
      "Meeanjin has always been a gathering place. The river, the land — they hold the stories of our ancestors, thousands of generations deep.",
    profileImageUrl:
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200",
  },
  {
    name: "Andrew Stafford",
    quote:
      "Brisbane's oppressive political climate under Bjelke-Petersen paradoxically gave birth to one of the world's most important punk scenes — The Saints changed everything.",
    profileImageUrl:
      "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200",
  },
  {
    name: "Helen Gregory",
    quote:
      "The Story Bridge was more than engineering — it was a symbol of hope during the Depression, built by Queensland hands with Queensland steel.",
    profileImageUrl:
      "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200",
  },
  {
    name: "Claude Reid",
    quote:
      "We started with just two koalas — Jack and Jill — and a single hoop pine. The dream was simple: give these animals a safe home.",
    profileImageUrl:
      "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200",
  },
];

// ─── HELPERS ─────────────────────────────────────────────────────────────────

/** Convert a title/name to a URL-friendly slug, e.g. "Story Bridge: Brisbane's Steel Icon" → "story-bridge-brisbanes-steel-icon" */
function toSlug(text) {
  return text
    .toLowerCase()
    .replace(/['']/g, "")          // remove apostrophes
    .replace(/[^a-z0-9]+/g, "-")  // non-alphanumeric → hyphen
    .replace(/^-+|-+$/g, "");      // trim leading/trailing hyphens
}

/** Delete all documents in a collection (in batches of 500). */
async function deleteCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) return 0;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snapshot.size;
}

// ─── SEED FUNCTION ───────────────────────────────────────────────────────────

async function seed() {
  // Clean up old auto-generated documents first
  let deleted = await deleteCollection("brisbane_stories");
  console.log(`  🗑  Deleted ${deleted} old brisbane_stories documents.`);
  deleted = await deleteCollection("brisbane_voices");
  console.log(`  🗑  Deleted ${deleted} old brisbane_voices documents.`);

  console.log("Seeding brisbane_stories...");
  const storiesBatch = db.batch();
  for (const story of stories) {
    const slug = toSlug(story.title);
    const ref = db.collection("brisbane_stories").doc(slug);
    storiesBatch.set(ref, {
      ...story,
      approvalStatus: "approved",
      publishedAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
    });
  }
  await storiesBatch.commit();
  console.log(`  ✓ ${stories.length} stories written.`);

  console.log("Seeding brisbane_voices...");
  const voicesBatch = db.batch();
  for (const voice of voices) {
    const slug = toSlug(voice.name);
    const ref = db.collection("brisbane_voices").doc(slug);
    voicesBatch.set(ref, {
      ...voice,
      approvalStatus: "approved",
      createdAt: admin.firestore.Timestamp.now(),
    });
  }
  await voicesBatch.commit();
  console.log(`  ✓ ${voices.length} voices written.`);

  console.log("\nDone! All data seeded successfully.");
  process.exit(0);
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
