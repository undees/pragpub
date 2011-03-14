Given /^I am (.+)$/ do |mood|
  $port.putc int_for(mood).to_s
end

When /^I ([^ ]+) my happiness$/ do |change|
  char = (change == 'increase') ? '+' : '-'
  $port.putc char
end

Then /^I should be (.+)$/ do |mood|
  $port.putc '?'
  $port.getc.to_i.should == int_for(mood)
end
