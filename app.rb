class App < Sinatra::Base
	
	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
	end

	def get_author(book_id)
		db = SQLite3::Database::new("./database/db.db")
		books = db.execute("SELECT name FROM authors WHERE id IN (SELECT author_id FROM 'authors-books-relations' WHERE book_id=?)", book_id)
		p books
	end

	enable:sessions

	# 404
	not_found do
		redirect('/')
	end

	get '/' do
		slim(:index)
	end


	get '/new_user/?' do
		slim(:new_user)
	end
	

	get '/all_books/?' do
		db = SQLite3::Database::new("./database/db.db")
		books = db.execute("SELECT * FROM books")
		get_author(15)
		"nice"
	end

	post '/new_user' do
		new_name = params[:name]
		new_password = params[:password]
		confirmed_password = params[:confirmed_password]
		if new_password == confirmed_password
			db = SQLite3::Database::new("./database/db.db")
			taken_name = db.execute("SELECT * FROM users WHERE name IS ?", new_name)
			if taken_name == []
				hashed_password = BCrypt::Password.create(new_password)
				db.execute("INSERT INTO users (name, password) VALUES (?,?)", [new_name, hashed_password])
				redirect('/')
			else
				session[:failure] = "Username is already taken."
				redirect('/new_user')
			end
		else
			session[:failure] = "Passwords didn't match. Please try again."
			redirect('/new_user')
		end
	end

	# Använd '/' för att URL:en inte ska ändras när inloggningen misslyckas.
	post '/login' do
		name = params[:name]
		password = params[:password]
		db = SQLite3::Database::new("./database/db.db")
		real_password = db.execute("SELECT password FROM users WHERE name=?", name)
		if real_password != [] && BCrypt::Password.new(real_password[0][0]) == password
			session[:user_id] = db.execute("SELECT id FROM users WHERE name=?", name)[0][0]
			redirect('/notes')
		else
			session[:failure] = "Login failed"
			redirect('/index')
		end
	end
end
