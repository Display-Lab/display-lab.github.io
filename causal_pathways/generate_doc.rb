#!/usr/bin/env ruby

require 'rdf'
require 'rdf/rdfxml'
require 'json'
require 'json/ld'
require 'net/http'
require 'uri'
require 'erb'
require 'pry'
include RDF

### Constants ###

# Ontology remotes
CPO_URI = "https://raw.githubusercontent.com/Display-Lab/cpo/master/cpo.owl"
PSDO_URI = "https://raw.githubusercontent.com/Display-Lab/psdo/master/psdo.owl"
SLOWMO_URI = "https://raw.githubusercontent.com/Display-Lab/slowmo/master/slowmo.owl"
BENCH_ACHIEVEMEMENT_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/bench_achievement.json"
BENCH_DIFF_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/bench_diff.json"
CONSISTENT_HIGH_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/consistent_high.json"
CONSISTENT_LOW_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/consistent_low.json"
GOAL_ACHIEVEMENT_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/goal_achievement.json"
GOAL_DIFF_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/goal_diff.json"
HIGH_BENCH_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/high_bench.json"
NEGATIVE_TREND_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/negative_trend.json"
POSITIVE_TREND_URI = "https://raw.githubusercontent.com/Display-Lab/knowledge-base/master/causal_pathways/positive_trend.json"

# List of causal pathways urls

CP_RELATIVE_DIR = File.join(File.dirname(__FILE__), '..', 'causal_pathways' )
CP_RELATIVE_DOCS_DIR = File.join(File.dirname(__FILE__), '..', '_causal_paths' )

CP_DIR = File.absolute_path CP_RELATIVE_DIR
CP_DOCS = File.absolute_path CP_RELATIVE_DOCS_DIR

CP_HTML_TEMPLATE = <<~HEREDOC
<!DOCTYPE html>
<html>
  <body>
    <details>
    <summary><b><%= name %></b></summary>
    <pre>
    <%= content %>
    </pre>
    </details>
  </body>
</html>
HEREDOC

CP_INDEX_TEMPLATE = <<~IDXDOC
<!DOCTYPE html>
<html>
  <body>
    <h1>Display Lab Knowledge Base</h1>
    <h2>Causal Pathways</h2>
    <ul>
    <% cp_names.each do |n| %>
      <li>
      <a href=\" <%= n %>.html \"> <%= n %> </a>
      </li>
    <% end %>
    </ul>
  </body>
</html>
IDXDOC

### Functions ###

# Get the causal pathways from remote
def fetch_causal_pathways(uri)
  p_uri = URI.parse(uri)
  response = Net::HTTP.get_response(p_uri)

  if(response.code != "200")
    puts "Unable to fetch #{uri}"
    abort
  end
  response.body
end

# Get the ontology from the remote
def fetch_ontology(uri)
  p_uri = URI.parse(uri)
  response = Net::HTTP.get_response(p_uri)

  if(response.code != "200")
    puts "Unable to fetch #{uri}"
    abort
  end

  response.body
end

# Return local file name
def retrieve_ontology(uri)
  case uri
  when CPO_URI
    file_path = File.join(Dir.tmpdir, "cpo.owl")
  when PSDO_URI
    file_path = File.join(Dir.tmpdir, "psdo.owl")
  when SLOWMO_URI
    file_path = File.join(Dir.tmpdir, "slowmo.owl")
  else
    puts "bad uri"
    abort
  end
  if !File.exists?(file_path)
    ontology = fetch_ontology(uri)
    File.open(file_path, "w") do |f|
      f.write(ontology)
    end
  end
  RDF::Graph.load(file_path, format: :rdfxml)
end

# Save causal pathways to disk
def retrieve_causal_pathways(uri)
  case uri
  when BENCH_ACHIEVEMEMENT_URI
    file_path = File.join(CP_RELATIVE_DIR, "bench_achievement.json")
  when BENCH_DIFF_URI
    file_path = File.join(CP_RELATIVE_DIR, "bench_diff.json")
  when CONSISTENT_HIGH_URI
    file_path = File.join(CP_RELATIVE_DIR, "consistent_high.json")
  when CONSISTENT_LOW_URI
    file_path = File.join(CP_RELATIVE_DIR, "consistent_low.json")
  when GOAL_ACHIEVEMENT_URI
    file_path = File.join(CP_RELATIVE_DIR, "goal_achievement.json")
  when GOAL_DIFF_URI
    file_path = File.join(CP_RELATIVE_DIR, "goal_diff.json")
  when HIGH_BENCH_URI
    file_path = File.join(CP_RELATIVE_DIR, "high_bench.json")
  when NEGATIVE_TREND_URI
    file_path = File.join(CP_RELATIVE_DIR, "negative_trend.json")
  when POSITIVE_TREND_URI
    file_path = File.join(CP_RELATIVE_DIR, "positive_trend.json")
  else
    puts "bad uri"
    abort
  end
  if !File.exists?(file_path)
    cp = fetch_causal_pathways(uri)
    File.open(file_path, "w") do |f|
      f.write(cp)
    end
  end
end
# Create a hash of IRI => labels from the graph of an ontology.
def extract_labels( graph )
  rdfschema = RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#")

  label_query = RDF::Query.new({
    term: { rdfschema.label => :label }
  })
  solutions = graph.query label_query
  zipped = solutions.map{|s| [s.term.value, s.label.value]}
  Hash[zipped]
end

# Read all json files from directory into an array of hashes
def read_json_from_dir( input_dir )
  cp_paths = Dir.glob(File.join(input_dir, '*.json'))

  cp_paths.map do |path|
    File.open(path){ |file| JSON.load file }
  end
end

# Substutite values in the hash that match the label mapping.
def substitute_labels(cp, labels)
  cp.each do |k, v|
    if v.is_a?(String) && labels.keys.include?(v)
      v.replace labels[v]
    elsif v.is_a?(Hash)
      substitute_labels v, labels
    elsif v.is_a?(Array)
      v.flatten.each { |x| substitute_labels(x, labels) if x.is_a?(Hash) }
    end
  end
  cp
end

# Given a causal pathway, return html using baked in html template
def generate_cp_html(cp)
  graph = cp['@graph'].first
  name = graph['name']
  content = JSON.pretty_generate(graph)
  ERB.new(CP_HTML_TEMPLATE).result(binding)
end

# Calculate file path for documenting html of a causal path
def generate_cp_html_path(cp)
  content = cp['@graph'].first
  name = content['name'].sub(/ /, '_')
  File.join(CP_RELATIVE_DOCS_DIR, "#{name}.html")
end

def generate_index_html(cp_list)
  cp_names = cp_list.map do |cp|
    content = cp['@graph'].first
    content['name'].sub(/ /, '_')
  end
  ERB.new(CP_INDEX_TEMPLATE).result(binding)
end

### SCRIPT START ###

puts "Generating."

# Load Ontologies
#   Grab from hard coded local location for now.
#   Use fetch_ontology to grap from remote
cpo_owl  = retrieve_ontology CPO_URI
psdo_owl = retrieve_ontology PSDO_URI
slowmo_owl = retrieve_ontology SLOWMO_URI

cpo_labels = extract_labels cpo_owl
psdo_labels = extract_labels psdo_owl
slowmo_labels = extract_labels slowmo_owl

all_labels = psdo_labels.merge cpo_labels, slowmo_labels

# Load KB Causal Pathways from local source
bench_achievement = retrieve_causal_pathways BENCH_ACHIEVEMEMENT_URI
bench_diff = retrieve_causal_pathways BENCH_DIFF_URI
consistent_high = retrieve_causal_pathways CONSISTENT_HIGH_URI
consisteng_log = retrieve_causal_pathways CONSISTENT_LOW_URI
goal_achievement = retrieve_causal_pathways GOAL_ACHIEVEMENT_URI
goal_diff = retrieve_causal_pathways GOAL_DIFF_URI
high_bench = retrieve_causal_pathways HIGH_BENCH_URI
negative_trend = retrieve_causal_pathways NEGATIVE_TREND_URI
positive_trend = retrieve_causal_pathways POSITIVE_TREND_URI

puts "Looking in #{CP_DIR} \n"
cp_list = read_json_from_dir CP_DIR
# Do label substitutions in values
cps_subbed = cp_list.map{|cp| substitute_labels(cp, all_labels) }

# Create html content
cps_html = cps_subbed.map{|cp| generate_cp_html cp}

# Create list of file names
cps_paths = cp_list.map{|cp| generate_cp_html_path cp}

# Write html to disk
Hash[cps_paths.zip(cps_html)].each do |path,html|
  File.open(path, 'w'){|file| file << html }
end

# Create index html
index = generate_index_html(cps_subbed)

# Write index to disk
index_path = File.join(CP_RELATIVE_DOCS_DIR, 'index.html')
File.open(index_path,'w'){|file| file << index}

puts "Done."
