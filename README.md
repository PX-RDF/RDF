# ProteomeXchange RDF
Conversion codes from PX-XML to PX-RDF

### Requirement
* [RDF.rb](https://github.com/ruby-rdf/rdf)
* [RDF::turtle](https://github.com/ruby-rdf/rdf-turtle)
 
### Usage
* ruby bin/pxxml2rdf.rb <PXID list file> (<PXID> optional for resume)
* e.g.
`ruby bin/pxxml2rdf.rb list/sampleidlist.txt`
