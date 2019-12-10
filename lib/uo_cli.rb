#!/usr/bin/ ruby

#*********************************************************************************
# URBANopt, Copyright (c) 2019, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#*********************************************************************************

require "uo_cli/version"
require "optparse"
require "urbanopt/geojson"
require "urbanopt/scenario"

module Urbanopt
  module CLI

    # Set up cli
    @options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: uo [flag] [ScenarioFileAbsolutePath] [FeatureFileAbsolutePath]\n" +
      "'example_project.json' in the example-geojson-project is an example of a FeatureFile\n" +
      "Assumes Scenario and Feature files are in the root directory of your project"
      opts.separator ""
      opts.separator "Flag options:"

      opts.on("-c", "--create", "Create files for the named scenario without running simulations") do
        @options[:action_type] == "Create"
      end
      opts.on("-r", "--run", "Create & Run simulations for the named scenario") do
        @options[:action_type] = "Run"
      end
      opts.on("-p", "--postprocess", "Aggregate results for the named scenario") do
        @options[:action_type] = "PostProcess"
      end
      opts.on("-d", "--delete", "Delete results from the named scenario") do
        @options[:action_type] = "Delete"
      end
    end.parse!

    # Strip the file type off the scenario file
    @scenario_file = "#{ARGV[0].split('.')[0]}"
    @feature_file = "#{ARGV[1]}"
    @root, @scenario_name = File.split(@scenario_file)

    # Gather the defining files of the district to be simulated\
    # params\
    # +scenario+:: _string_ Path to csv file that defines the scenario\
    # +featureFile+:: _string_ Path to Feature File used to describe set of features in the district
    def self.run_func(scenario, featureFile)
      name = "#{@scenario_name.capitalize}"
      root_dir = @root
      run_dir = "#{root_dir}/run/#{@scenario_name.downcase}"
      feature_file_path = "#{featureFile}"
      csv_file = "#{scenario}.csv"
      mapper_files_dir = "#{root_dir}/mappers/"
      num_header_rows = 1

      feature_file = URBANopt::GeoJSON::GeoFile.from_file(feature_file_path)
      scenario_output = URBANopt::Scenario::ScenarioCSV.new(name, root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
      return scenario_output
    end


    # Perform CLI actions
    if @options[:action_type] == "Delete"
      puts "Deleting previous results from '#{@scenario_name}'..."
      run_func(@scenario_file, @feature_file).clear
      # TODO: improve the `clear` method to also delete the named scenario folder inside the run directory
      # (not just children of the named scenario folder)
    end
    if @options[:action_type] == "Create"
      puts "Creating files for #{@scenario_name} without running any simulations..."
      scenario_files = URBANopt::Scenario::ScenarioRunnerOSW.new
      scenario_files.create_simulation_files(run_func(@scenario_file, @feature_file))
      # TODO: Save results from create_simulation_files. How does the save method in ScenarioDefaultPostProcessor work?
    end
    if @options[:action_type] == "PostProcess"
      puts "Aggregating results across all of '#{@scenario_name}'..."
      scenario_result = URBANopt::Scenario::ScenarioDefaultPostProcessor.new(run_func(@scenario_file, @feature_file)).run
      scenario_result.save
    end
    if @options[:action_type] == "Run"
      puts "Simulating all features in '#{@scenario_name}'..."
      scenario_runner = URBANopt::Scenario::ScenarioRunnerOSW.new
      scenario_runner.run(run_func(@scenario_file, @feature_file))
    end
  end
end
