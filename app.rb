class App < Sinatra::Base
	
	def failure
		error = session[:failure]
		session[:failure] = nil
		return error
	end

	def get_author(book_id)
		db = SQLite3::Database::new("./database/db.db")
		names = db.execute("SELECT name FROM authors WHERE id IN (SELECT author_id FROM 'authors-books-relations' WHERE book_id=?)", book_id)
		names.flatten!
	end

	def get_genre(genre_id)
		db = SQLite3::Database::new("./database/db.db")
		names = db.execute("SELECT name FROM genres WHERE id=?", genre_id)
		names[0][0]
	end

	def get_books_by_genre(genre_id)
		db = SQLite3::Database::new("./database/db.db")
		books = db.execute("SELECT * FROM books WHERE genre_id=?", genre_id)
		books.each do |book|
			book << get_author(book[0])
		end
		books
	end

	def get_all_book_info
		db = SQLite3::Database::new("./database/db.db")
		books = db.execute("SELECT * FROM books")
		books.each do |book|
			book[-1] = get_genre(book[-1])
			book << get_author(book[0])
		end
		books
	end
	enable:sessions

	# # 404
	# not_found do
	# 	redirect('/')
	# end

	get '/' do
		slim(:index)
	end


	get '/new_user/?' do
		slim(:new_user)
	end
	

	get '/all_books/?' do
		books = get_all_book_info()
		slim(:all_books, locals: { books: books })
	end

	get '/genre_list/?' do
		db = SQLite3::Database::new("./database/db.db")
		genres = db.execute("SELECT * FROM genres")
		genres.each do |genre|
			genre << get_books_by_genre(genre[0])
		end
		slim(:genre_list, locals: { genres:genres })
	end

	get '/book/:id/?' do
		db = SQLite3::Database::new("./database/db.db")
		books = db.execute("SELECT * FROM books WHERE id=?", params[:id])
		book = books[0]
		book[-1] = get_genre(book[-1])
		book << get_author(book[0])
		slim(:single_book, locals: { book:book })
	end

	get '/random_book/?' do
		db = SQLite3::Database::new("./database/db.db")
		book_ids = db.execute("SELECT id FROM books")
		choise = book_ids.sample[0]
		redirect("/book/#{choise}")
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
