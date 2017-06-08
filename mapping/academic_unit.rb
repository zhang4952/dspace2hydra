# frozen_string_literal: true
# :nocov:
module Mapping
  class AcademicUnit
    require 'csv'
    require 'Date'

    extend Extensions::BasicValueHandler

    # https://docs.google.com/spreadsheets/d/1Z_G-LO65NYf5BqkMH0koLzG5DoZ8KD3yAapViWCxiJw/edit#gid=1029520529
    COLLECTION_CSV_FILE = '../lookup/collectionlist.csv'
    # https://docs.google.com/spreadsheets/d/1S-OKXl4-yQUYGufE9lYwQ1aLda0MyA_XsEs-lY5pYlA/edit#gid=2028992807
    ETD_CSV_FILE = '../lookup/etd_academic_unit.csv'
    # https://docs.google.com/spreadsheets/d/1Z_G-LO65NYf5BqkMH0koLzG5DoZ8KD3yAapViWCxiJw/edit#gid=877024543
    OTHER_AFFILIATIONS_CSV_FILE = '../lookup/other_affiliations_academic_unit.csv'
    # opaquenamespace.org/ns/osuAcademicUnits.jsonld
    ACADEMIC_UNITS_JSONLD_FILE = '../lookup/osuAcademicUnits.jsonld'

    def self.get_uris(item_detail, *_args)
      collections = collection_csv
      academic_units = academic_units_hash

      affiliation_name = find_department_or_college_affiliation(collections, item_detail[:owner_id])
      other_affiliation_uri = find_other_affiliation(collections, item_detail[:owner_id], other_affiliations_csv)
      if affiliation_name
        found_academic_units = find_academic_units(academic_units, affiliation_name)
      end

      if item_detail[:work_type].casecmp('etd').zero? && found_academic_units.nil?
        graduation_year = graduation_date(item_detail[:metadata])
        # IF ETD, check the etds for the academic unit uri
        handle = handle_uri(item_detail[:metadata])
        etd = etd_csv.find { |e| e['dc.identifier.uri'].casecmp(handle).zero? }
        return nil if etd['Department'].nil? && etd['College'].nil?
        label = etd['Department'].nil? ? etd['College'] : etd['Department']
        found_academic_units = find_academic_units(academic_units, label, graduation_year)
      end
      found_academic_units.flatten!
      [
        { field_name: 'other_affiliation', value: other_affiliation_uri },
        { field_name: 'acedemic_affiliation', value: found_academic_units }
      ]
    end

    private

    def self.handle_uri(metadata)
      handle_node = metadata['identifier'].find { |n| n.qualifier.qualifier.casecmp('uri').zero? }
      handle = handle_node.qualifier.run_method
    end

    def self.graduation_date(metadata)
      graduation_date_node = metadata['description'].select { |n| n.qualifier.qualifier.casecmp('default').zero? }
      graduation_date = graduation_date_node.map { |n| n.qualifier.run_method }.find { |f| f.first[:field_name].casecmp('graduation_year').zero? }
      graduation_date.first[:value]
    end

    def self.collection_csv
      CSV.read(File.join(File.dirname(__FILE__), COLLECTION_CSV_FILE), headers: true, encoding: 'UTF-8').map(&:to_hash)
    end

    def self.etd_csv
      CSV.read(File.join(File.dirname(__FILE__), ETD_CSV_FILE), headers: true, encoding: 'UTF-8').map(&:to_hash)
    end

    def self.other_affiliations_csv
      CSV.read(File.join(File.dirname(__FILE__), OTHER_AFFILIATIONS_CSV_FILE), headers: true, encoding: 'UTF-8').map(&:to_hash)
    end

    def self.academic_units_hash
      hash = JSON.parse(File.read(File.join(File.dirname(__FILE__), ACADEMIC_UNITS_JSONLD_FILE)))
      hash.dig('@graph')
    end

    def self.find_department_or_college_affiliation(collections, owner_id)
      collection = collections.find { |c| c['collection_handle'] === owner_id }
      return nil if collection['Department Affiliation'].nil? && collection['College Affiliation'].nil?
      collection['Department Affiliation'] || collection['College Affiliation']
    end

    def self.find_other_affiliation(collections, owner_id, other_affiliations)
      dspace_collection = collections.find { |c| c['collection_handle'] === owner_id }
      label = dspace_collection['Other Affiliation']
      return nil unless label
      found = other_affiliations.find { |row| row['Name'].casecmp(label).zero? }
      raise "#{OTHER_AFFILIATIONS_CSV_FILE} missing expected entry and uri, '#{label}'" unless found.count
      found['URI']
    end

    def self.find_academic_units(academic_units, label, graduation_year = nil)
        academic_units = select_academic_units_by_label(academic_units, label)
        academic_units = select_academic_units_having_date_range(academic_units, graduation_year) if graduation_year
        return nil unless academic_units.count
        academic_units.map { |a| a['@id'] }
    end

    def self.select_academic_units_by_label(academic_units, label)
      academic_units.select do |a|
        found = a.dig('rdfs:label', '@value')
        next if found.nil?
        a.dig('rdfs:label', '@value').casecmp(label).zero?
      end
    end

    def self.select_academic_units_having_date_range(academic_units, date)
      academic_units.select do |a|
        found = a.dig('dc:date')
        return false if found.nil?
        dates = found.split(',')
        dates.keep_if do |d|
          from, to = d.split('/')
          to = to.casecmp('open').zero? ? ::DateTime.now.to_date : ::Date.new(to, 1, 1)
          from = ::Date.new(from.to_i, 1, 1)
          date = ::Date.new(date.to_i, 12, 31)
          date >= from && date <= to
        end
        dates.count > 0
      end
    end
  end
end