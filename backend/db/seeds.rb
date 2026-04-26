user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end
puts "User created: #{user.email}"

puts "Seeding complete!"
