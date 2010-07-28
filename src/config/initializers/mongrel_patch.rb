# monkey patch to make mongrel compatible with rails 2.3.5
# fixes faulty redirection issue.
# TODO : ditch mongrel and switch to passenger instead.
class Mongrel::CGIWrapper
  def header_with_rails_fix(options = 'text/html')
    @head['cookie'] = options.delete('cookie').flatten.map { |v| v.sub(/^\n/,'') } if options.class != String and options['cookie']
    header_without_rails_fix(options)
  end
  alias_method_chain(:header, :rails_fix)
end if (Rails.version == '2.3.5' or Rails.version == '2.3.8') and Gem.available?('mongrel', Gem::Requirement.new('~>1.1.5')) and self.class.const_defined?(:Mongrel)

