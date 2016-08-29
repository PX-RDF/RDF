require 'net/http'
require 'uri'
require 'rexml/document'
require 'rdf'
require 'rdf/turtle'
require 'json/ld'
include RDF

file = ARGV[0] || "../list/pxidlist160827.txt"

@dbs = {
  "PRIDE"        => "https://www.ebi.ac.uk/pride/archive/",
  "PeptideAtlas" => "http://www.peptideatlas.org/",
  "PASSEL"       => "http://www.peptideatlas.org/passel/",
  "testRepo"     => "http://testrepo/",
  "MassIVE"      => "http://massive.ucsd.edu/",
  "iProX"        => "http://www.iprox.cn/",
  "jPOST"        => "https://repository.jpostdb.org/"
}
        
@cvs = {
  "PRIDE"  => "https://raw.githubusercontent.com/PRIDE-Utilities/pride-ontology/master/pride_cv.obo#PRIDE:",
  "MS"     => "https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo#MS:",
  "PSI-MS" => "https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo#MS:",
  "MOD"    => "https://raw.githubusercontent.com/MICommunity/psidev/master/psi/mod/data/PSI-MOD.obo#MOD:",
  "UNIMOD" => "http://www.unimod.org/obo/unimod.obo#UNIMOD:",
  "BTO"    => "http://purl.obolibrary.org/obo/BTO_",
  "NEWT"   => "http://identifiers.org/taxonomy/",
  "DOID"   => "http://www.disease-ontology.org/?id=DOID:",
  "SEP"    => "https://raw.githubusercontent.com/HUPO-PSI/gelml/master/CV/sep.obo#sep:"
}

@month = {
  "Jan" => "01",
  "Feb" => "02",
  "Mar" => "03",
  "Apr" => "04",
  "May" => "05",
  "Jun" => "06",
  "Jul" => "07",
  "Aug" => "08",
  "Sep" => "09",
  "Oct" => "10",
  "Nov" => "11",
  "Dec" => "12",
}


def get_xml(id)
  Net::HTTP.get URI.parse("http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=#{id}&outputMode=XML&test=no")
end


def cv(cv)
  cvs       = Hash.new
  
  cvs[:ns], cvs[:id] = cv.attributes['accession'].split(":")
  cvs[:accession]    = cv.attributes['accession']
  cvs[:cvRef]        = cv.attributes['cvRef']
  cvs[:name]         = cv.attributes['name']
  
  cvs[:unitNs], cvs[:unitId] = cv.attributes['unitAccession'].split(":") if cv.attributes['unitAccession']
  cvs[:unitAccession]        = cv.attributes['unitAccession']            if cv.attributes['unitAccession']
  cvs[:unitCvRef]            = cv.attributes['unitCvRef']                if cv.attributes['unitCvRef']
  cvs[:unitName]             = cv.attributes['unitName']                 if cv.attributes['unitName']
  cvs[:value]                = cv.attributes['value']                    if cv.attributes['value']
  
  if cvs[:cvRef] == "NEWT"
    cvs[:id] = cvs[:ns]
  end
  
  if cvs[:id] # some modifications don't have id. WHY?
    cvs[:uri] = RDF::URI(@cvs[cvs[:cvRef]] + cvs[:id])
  else
    cvs[:uri] = RDF::URI(@cvs[cvs[:cvRef]] + "XXXX")
  end
  cvs[:unit_uri] = RDF::URI(@cvs[cvs[:unitCvRef] ] + cvs[:unitId]) if cvs[:unitCvRef] && cvs[:unitId]
  
  return cvs
end


def xml2rdf(xml)
  #########################################################
  #  define PREFIX
  #########################################################
  rdf    = RDF::Vocabulary.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
  rdfs   = RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#")
  dc     = RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/")
  dct    = RDF::Vocabulary.new("http://purl.org/dc/terms/")
  skos   = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
  owl    = RDF::Vocabulary.new("http://www.w3.org/2002/07/owl#")
  pav    = RDF::Vocabulary.new("http://purl.org/pav/")
  sio    = RDF::Vocabulary.new("http://semanticscience.org/resource/")
  foaf   = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")
  bibo   = RDF::Vocabulary.new("http://purl.org/ontology/bibo/")
  prism  = RDF::Vocabulary.new("http://prismstandard.org/namespaces/1.2/basic/")
  px     = RDF::Vocabulary.new("https://raw.githubusercontent.com/PX-RDF/ontology/master/px.owl#")
  pride  = RDF::Vocabulary.new("https://raw.githubusercontent.com/PRIDE-Utilities/pride-ontology/master/pride_cv.obo#PRIDE:")
  ms     = RDF::Vocabulary.new("https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo#MS:")
  mod    = RDF::Vocabulary.new("https://raw.githubusercontent.com/MICommunity/psidev/master/psi/mod/data/PSI-MOD.obo#MOD:")
  unimod = RDF::Vocabulary.new("http://www.unimod.org/obo/unimod.obo#")
  
  
  # terms
  documentVersion = RDF::URI("http://semanticscience.org/resource/SIO_000186")
  hasValue        = RDF::URI("http://semanticscience.org/resource/SIO_000300")
  hasSource       = RDF::URI("http://semanticscience.org/resource/SIO_000253")
  doi             = RDF::URI("https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo#1001922")
  
  
  g   = RDF::Graph.new
  doc = REXML::Document.new(xml)
  

  #########################################################
  #  generate RDF
  #########################################################
  id = doc.elements['ProteomeXchangeDataset'].attributes['id']
  subject = RDF::URI("http://proteomecentral.proteomexchange.org/dataset/#{id.sub(/\..+$/, "")}")
  
  # ProteomeXchangeDataset: Top-level element
  g << [subject, RDF.type, px.ProteomeXchangeDatasetType]
  
  
  ## ChangeLog min=0 max=1
  if e = doc.elements['ProteomeXchangeDataset/ChangeLog']    
    e.elements.each do |element|
      changeLogEntry = RDF::Node.new
      g << [subject, px.changeLogEntry, changeLogEntry]
      g << [changeLogEntry, RDF.type, px.ChangeLogEntryType]
      g << [changeLogEntry, dct.date, RDF::Literal::Date.new(element.attributes['date'])] if element.attributes['date']
      g << [changeLogEntry, documentVersion, element.attributes['version']] if element.attributes['version'] #document version
      g << [changeLogEntry, hasValue, element.text] if element.text #has value
    end
  end


  ## DatasetSummary min=1 max=1
  e = doc.elements['ProteomeXchangeDataset/DatasetSummary']
  host = RDF::URI(@dbs[e.attributes['hostingRepository']])
  
  g << [subject, dct.date, RDF::Literal::Date.new(e.attributes['announceDate'])]
  g << [subject, px.hostingRepository, host]
  g << [host, RDF.type, px.HostingRepositoryType]
  g << [host, rdfs.label, e.attributes['hostingRepository']]
  g << [subject, dct.title, e.attributes['title']]
  g << [subject, rdfs.label, e.attributes['title']]
  
  ### Description min=1 max=1
  g << [subject, dc.description, e.elements['Description'].text.chomp]
  
  ### Review Level min=1 max=1
  cvs = cv(e.elements['ReviewLevel/cvParam'])
  g << [subject, px.reviewLevel, cvs[:uri]]
  g << [cvs[:uri], RDF.type, px.ReviewLevelType]
  g << [cvs[:uri], rdfs.label, cvs[:name]]

  ### RepositorySupport min=1 max=1
  cvs = cv(e.elements['RepositorySupport/cvParam'])
  g << [subject, px.repositorySupport, cvs[:uri]]
  g << [cvs[:uri], RDF.type, px.RepositorySupportType]
  g << [cvs[:uri], rdfs.label, cvs[:name]]


  ## DatasetIdentifierList min=1 max=1
  ### subelement
  #### DatasetIdentifier min=1 max=unbounded
  doc.elements.each('ProteomeXchangeDataset/DatasetIdentifierList/DatasetIdentifier/cvParam') do |element|
    cvs = cv(element)
    g << [subject, cvs[:uri], cvs[:value]]
    g << [cvs[:uri], RDF.type, owl.DatatypeProperty]
    g << [cvs[:uri], rdfs.label, cvs[:name]]
    
    if cvs[:accession] == "MS:1001921"            # ProteomeXchange accession number version number
      g << [subject, pav.version, cvs[:value]]
    elsif cvs[:accession] == "MS:1001919"         # ProteomeXchange accession number
      g << [subject, dct.identifier, cvs[:value]]
    elsif cvs[:accession] == "MS:1001922"         # Digital Object Identifier (DOI)
      g << [subject, rdfs.seeAlso, RDF::URI("https://doi.org/#{cvs[:value]}")]
    end
  end
  
  
  ## DatasetOriginList min=1 max=1
  ### subelement
  #### DatasetOrigin min=1 max=1
  doc.elements.each('ProteomeXchangeDataset/DatasetOriginList/DatasetOrigin/cvParam') do |element|
    cvs = cv(element)
    if cvs[:value]
      g << [subject, hasSource, RDF::URI("http://proteomecentral.proteomexchange.org/dataset/#{cvs[:value]}")] # has source
    else
      g << [subject, px.datasetOrigin, cvs[:uri]]
      g << [cvs[:uri], RDF.type, px.DatasetOriginType]
      g << [cvs[:uri], rdfs.label, cvs[:name]]
    end
  end
  
  
  ## SpeciesList min=1 max=1
  ### subelement
  #### Species min=1 max=unbounded
  doc.elements.each('ProteomeXchangeDataset/SpeciesList/Species') do |element|
    species = RDF::Node.new
    g << [subject, px.species, species]
    g << [species, RDF.type, px.SpeciesType]
    
    element.elements.each do |subelement|
      cvs = cv(subelement)
      if cvs[:accession] == "MS:1001467"
        g << [species, rdfs.seeAlso, RDF::URI("http://identifiers.org/taxonomy/#{cvs[:value]}")]
        g << [species, rdfs.seeAlso, RDF::URI("http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=#{cvs[:value]}")]
        g << [species, dct.identifier, cvs[:value]]
      elsif cvs[:accession] == "MS:1001469"
        g << [species, rdfs.label, cvs[:value]]
      elsif cvs[:accession] == "MS:1001468"
        g << [species, skos.altLabel, cvs[:value]]
      end
      g << [species, cvs[:uri], cvs[:value]]
      g << [cvs[:uri], RDF.type, owl.DatatypeProperty]
      g << [cvs[:uri], rdfs.label, cvs[:name]]
    end
  end
  
  
  ## InstrumentList min=1 max=1
  ### subelement
  #### Instrument min=1 max=unbounded
  doc.elements.each('ProteomeXchangeDataset/InstrumentList/Instrument') do |element|
    element.elements.each do |subelement|
      cvs = cv(subelement)
      g << [subject, px.instrument, cvs[:uri]]
      g << [cvs[:uri], RDF.type, px.InstrumentType]
      g << [cvs[:uri], dct.identifier, element.attributes['id']]
      
      if cvs[:value]
        g << [cvs[:uri], rdfs.label, cvs[:value]]
      else
        g << [cvs[:uri], rdfs.label, cvs[:name]]        
      end 
    end
  end
  
  
  ## ModificationList min=1 max=1
  doc.elements.each('ProteomeXchangeDataset/ModificationList/cvParam') do |element|
    cvs = cv(element)
    g << [subject, px.modification, cvs[:uri]]
    g << [cvs[:uri], RDF.type, px.ModificationType]
    g << [cvs[:uri], rdfs.label, cvs[:name]]
    g << [cvs[:uri], hasValue, cvs[:value]] if cvs[:value] #has value
  end
  
  
  ## ContactListType min=1 max=1
  doc.elements.each('ProteomeXchangeDataset/ContactList/Contact') do |element|
    contributor = RDF::Node.new
    g << [subject, dct.contributor, contributor]
    g << [contributor, RDF.type, foaf.Person]
    g << [contributor, dct.identifier, element.attributes['id']]
    
    element.elements.each do |subelement|
      cvs = cv(subelement)
      if cvs[:accession] == "MS:1002332" || cvs[:accession] == "MS:1002037" # MS:1002332 => "lab head", MS:1002037 => "dataset submitter"
        g << [contributor, RDF.type, cvs[:uri]]
        g << [cvs[:uri], RDF.type, owl.Class]
        g << [cvs[:uri], rdfs.subClassOf, px.ContactType]
        g << [cvs[:uri], rdfs.label, cvs[:name]]
      else 
        g << [contributor, cvs[:uri], cvs[:value]]
        g << [cvs[:uri], RDF.type, owl.DatatypeProperty]
        g << [cvs[:uri], rdfs.label, cvs[:name]]
        
        if cvs[:accession] == "MS:1000586" # "contact name"
          g << [contributor, foaf.name, cvs[:value]]
        elsif cvs[:accession] == "MS:1000589" # "contact email"
          g << [contributor, foaf.mbox, RDF::URI(cvs[:value])]
        end
      end
    end
  end
  
  
  ## PublicationList min=1 max=1
  doc.elements.each('ProteomeXchangeDataset/PublicationList/Publication') do |element|
    publication = RDF::Node.new
    g << [subject, dct.references, publication]
    g << [publication, RDF.type, px.PublicationType]
    g << [publication, dct.identifier, element.attributes['id']]
    
    element.elements.each do |subelement|
      cvs = cv(subelement)
      if cvs[:accession] == "PRIDE:0000432" || cvs[:accession] == "PRIDE:0000412" # PRIDE:0000432 => "Dataset with its publication pending", PRIDE:0000412 => "Dataset with no associated published manuscript"
        g << [publication, RDF.type, cvs[:uri]]
        g << [cvs[:uri], RDF.type, owl.Class]
        g << [cvs[:uri], rdfs.label, cvs[:name]]
      #elsif cvs[:accession] == "PRIDE:0000400" # Reference
        #g << [publication, hasValue, cvs[:value]] # has value
      elsif cvs[:accession] == "MS:1001922" # Digital Object Identifier (DOI)
        cvs[:value] = "http://dx.doi.org/" + cvs[:value] unless cvs[:value] =~ /^http/
        g << [publication, rdfs.seeAlso, RDF::URI(cvs[:value])]
      elsif cvs[:accession] == "MS:1000879" # PubMed identifier
        g << [publication, RDF.type, bibo.Article]
        g << [publication, bibo.pmid, cvs[:value]]
        g << [publication, rdfs.seeAlso, RDF::URI("http://identifiers.org/pubmed/#{cvs[:value]}")]
        g << [publication, rdfs.seeAlso, RDF::URI("http://www.ncbi.nlm.nih.gov/pubmed/#{cvs[:value]}")]
        
        sleep(1) # API access must be less than 3 times per second according to NCBI E-utility guideline
        pubmed  = Net::HTTP.get URI.parse("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=#{cvs[:value]}&retmode=xml")
        pubmed  = REXML::Document.new(pubmed)
        article = pubmed.elements['PubmedArticleSet/PubmedArticle/MedlineCitation/Article/']
        #doi     = article.elements['ELocationID'].text if article.elements['ELocationID'].attributes['EIdType'] == "doi"
        doi     = pubmed.elements['PubmedArticleSet/PubmedArticle/PubmedData/ArticleIdList/ArticleId'].text if pubmed.elements['PubmedArticleSet/PubmedArticle/PubmedData/ArticleIdList/ArticleId'].attributes['IdType'] == "doi"
        year    = article.elements['Journal/JournalIssue/PubDate/Year'].text
        month   = @month[article.elements['Journal/JournalIssue/PubDate/Month'].text] if article.elements['Journal/JournalIssue/PubDate/Month']
        
        if day = article.elements['Journal/JournalIssue/PubDate/Day']
          day = day.text
          day = "0#{day}" if day.length == 1
        end
        
        g << [publication, dct.title, article.elements['ArticleTitle'].text]
        g << [publication, prism.publicationName, article.elements['Journal/Title'].text]
        g << [publication, rdfs.seeAlso, RDF::URI("http://dx.doi.org/#{doi}")]
        g << [publication, dc.date, year]
        g << [publication, prism.publicationDate, RDF::Literal::Date.new("#{year}-#{month}-#{day}")] if month && day
        
        # authors
        article.elements.each('AuthorList/Author') do |author|
          name = [author.elements['ForeName'].text, author.elements['LastName'].text].join("\s")
          g << [publication, dc.creator, name]
        end
      end
    end
  end
  
  
  ## KeywordList min=1 max=1
  doc.elements.each('ProteomeXchangeDataset/KeywordList/cvParam') do |element|
    g << [subject, dc.subject, element.attributes['value']]
  end
  
  
  ## FullDatasetLinkList min=1 max=1
  ### subelement
  #### FullDatasetLink min=1 max=unbounded
  doc.elements.each('ProteomeXchangeDataset/FullDatasetLinkList/FullDatasetLink/cvParam') do |element|
    cvs = cv(element)
    g << [subject, rdfs.seeAlso, RDF::URI(cvs[:value])]
    g << [RDF::URI(cvs[:value]), RDF.type, cvs[:uri]]
    g << [cvs[:uri], RDF.type, owl.Class]
    g << [cvs[:uri], rdfs.label, cvs[:name]]
  end
  
  
  ## DatasetFileList min=0 max=1
  if e = doc.elements['ProteomeXchangeDataset/DatasetFileList']
    e.elements.each do |element|
      datasetFile = RDF::Node.new
      g << [subject, px.datasetFile, datasetFile]
      g << [datasetFile, RDF.type, px.DatasetFileType]
      
      g << [datasetFile, dct.identifier, element.attributes['id']]
      g << [datasetFile, rdfs.label, element.attributes['name']]
      
      element.elements.each do |subelement|
        cvs = cv(subelement)
        g << [datasetFile, rdfs.seeAlso, RDF::URI(cvs[:value])]
        g << [RDF::URI(cvs[:value]), RDF.type, cvs[:uri]]
        g << [cvs[:uri], RDF.type, owl.Class]
        g << [cvs[:uri], rdfs.label, cvs[:name]]
      end
    end
  end
  
  
  ## RepositoryRecordList min=0 max=1
  if e = doc.elements['ProteomeXchangeDataset/RepositoryRecordList']
    e.elements.each do |subelement|
      repositoryRecord = RDF::Node.new
      g << [subject, px.repositoryRecord, repositoryRecord]
      g << [repositoryRecord, RDF.type, px.RepositoryRecordType]
      
      ##### attributes
      host = RDF::URI(@dbs[subelement.attributes['repositoryID']])
      g << [repositoryRecord, dct.title, subelement.attributes['name']]
      g << [repositoryRecord, dct.identifier, subelement.attributes['recordID']]
      g << [repositoryRecord, rdfs.seeAlso, RDF::URI(subelement.attributes['uri'])]
      g << [repositoryRecord, px.hostingRepository, host]
      g << [host, RDF.type, px.HostingRepositoryType]
      g << [host, rdfs.label, subelement.attributes['repositoryID']]
      g << [repositoryRecord, rdfs.label, subelement.attributes['label']] if subelement.attributes['label']
      
      ##### subsubelement
      ###### SourceFileRef min=0 max=unbounded
      subelement.elements.each('SourceFileRef') do |sse|
        ref = RDF::Node.new
        g << [repositoryRecord, px.sourceFileRef, ref]
        g << [ref, RDF.type, px.refType]
        g << [ref, dct.identifier, sse.attributes['ref']]
      end
      
      ###### PublicationRef min=0 max=unbounded
      subelement.elements.each('PublicationRef') do |sse|
        ref = RDF::Node.new
        g << [repositoryRecord, px.publicationRef, ref]
        g << [ref, RDF.type, px.refType]
        g << [ref, dct.identifier, sse.attributes['ref']]
      end
      
      ###### InstrumentRef min=0 max=unbounded
      subelement.elements.each('InstrumentRef') do |sse|
        ref = RDF::Node.new
        g << [repositoryRecord, px.instrumentRef, ref]
        g << [ref, RDF.type, px.refType]
        g << [ref, dct.identifier, sse.attributes['ref']]
      end
      
      ###### SampleList min=0 max=1
      if sse = subelement.elements['SampleList']        
        # sub3element
        ## Sample min=1 max=unbounded
        sse.elements.each do |s3e|
          sample = RDF::Node.new
          g << [repositoryRecord, px.sample, sample]
          g << [sample, RDF.type, px.SampleType]
          
          ### attribute
          g << [sample, rdfs.label, s3e.attributes['name']]
          
          ### sub4elelemt
          s3e.elements.each do |s4e|
            cvs = cv(s4e)
            g << [sample, rdfs.seeAlso, cvs[:uri]]
            g << [cvs[:uri], RDF.type, owl.Class]
            g << [cvs[:uri], rdfs.label, cvs[:name]]
          end
        end
      end
      
      ###### ModificationList min=0 max=1
      if sse = subelement.elements['ModificationList']
        modificationList = RDF::Node.new
        g << [repositoryRecord, px.modificationList, modificationList]
        g << [modificationList, RDF.type, px.ModificationListType]
        
        # sub3element
        sse.elements.each do |s3e|
          cvs = cv(s3e)
          g << [modificationList, rdfs.seeAlso, cvs[:uri]]
          g << [cvs[:uri], RDF.type, px.ModificationType]
          g << [cvs[:uri], rdfs.label, cvs[:name]]
          g << [cvs[:uri], hasValue, cvs[:value]] if cvs[:value]
        end
      end
    end
  end

  return g
end

# for test
#xml = get_xml("PXD003666")
#puts xml2rdf(xml).dump(:ttl)


# main
#=begin
f = File.open(file).read.split("\n")
if skip = ARGV[1]
  f.shift(f.index(skip) + 1)
end

f.each do |line|
  line = line.chomp
  xml = get_xml(line)
  g = xml2rdf(xml)
  
  out = File.open("./rdf/#{line}.ttl", "w")
  
  # output json-ld format
  #puts g.dump(:jsonld, prefixes:{
  # output turtle format
  out.puts g.dump(:ttl, prefixes:{
    rdf:    "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs:   "http://www.w3.org/2000/01/rdf-schema#",
    dc:     "http://purl.org/dc/elements/1.1/",
    dct:    "http://purl.org/dc/terms/",
    skos:   "http://www.w3.org/2004/02/skos/core#",
    owl:    "http://www.w3.org/2002/07/owl#",
    pav:    "http://purl.org/pav/",
    sio:    "http://semanticscience.org/resource/",
    foaf:   "http://xmlns.com/foaf/0.1/",
    bibo:   "http://purl.org/ontology/bibo/",
    prism:  "http://prismstandard.org/namespaces/1.2/basic/",
    px:     "https://raw.githubusercontent.com/PX-RDF/ontology/master/px.owl#",
    pride:  "https://raw.githubusercontent.com/PRIDE-Utilities/pride-ontology/master/pride_cv.obo#PRIDE:",
    ms:     "https://raw.githubusercontent.com/HUPO-PSI/psi-ms-CV/master/psi-ms.obo#MS:",
    mod:    "https://raw.githubusercontent.com/MICommunity/psidev/master/psi/mod/data/PSI-MOD.obo#MOD:",
    unimod: "http://www.unimod.org/obo/unimod.obo#UNIMOD:",
    xsd:    "http://www.w3.org/2001/XMLSchema#"
  })
  
  out.close
  puts line
end
#=end