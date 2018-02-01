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

	def loan_possible(book_id)
		remove_old_loans
		db = SQLite3::Database::new("./database/db.db")
		user_id = session[:user_id]
		if user_id
			loans = db.execute("SELECT * FROM loans WHERE user_id=? AND book_id=?", [user_id, book_id])
			available_books = db.execute("SELECT available FROM books WHERE id=?", book_id)
			if loans.empty? && available_books[0][0] > 0
				return true
			end
		end
		false
	end

	def new_loan(book_id)
		db = SQLite3::Database::new("./database/db.db")
		if loan_possible(book_id)
			db.execute("UPDATE books SET available = available - 1 WHERE id = ?", book_id)
			db.execute("INSERT INTO loans VALUES (?, ?, ?)", [session[:user_id], book_id, Time.now.to_i + 20])
			true
		else
			false
		end
	end

	def remove_old_loans
		db = SQLite3::Database::new("./database/db.db")
		time = Time.now.to_i
		old_loans = db.execute("SELECT book_id FROM loans WHERE loan_time < ?", time)
		db.execute("DELETE FROM loans WHERE loan_time < ? ", time)
		old_loans.each do |loan|
			db.execute("UPDATE books SET available = available + 1 WHERE id = ?", loan[0])
		end
	end

	def get_all_loans()
		db = SQLite3::Database::new("./database/db.db")
		user = session[:user_id]
		if user
			user_loans = db.execute("SELECT book_id FROM loans WHERE user_id = ?", user)
			return user_loans
		else
			return nil
		end
	end

	def get_book(book_id)
		db = SQLite3::Database::new("./database/db.db")
		book_data = db.execute("SELECT * FROM books WHERE id = ?", book_id)
		book_data = book_data[0]
		book_info = { id: book_data[0], name: book_data[1]}
		book_info[:genre] = get_genre(book_data[3])
		book_info[:authors] = get_author(book_data[0])
		book_info
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
		remove_old_loans
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

	get '/loan/:id/?' do
		id = params[:id]
		if new_loan(id)
			redirect("/book/#{id}")
		else
			"Failed"
		end
	end

	get '/my_books/?' do
		loans = get_all_loans()
		if loans
			slim(:my_books, locals:{ loans: loans })
		else
			redirect('/')
		end
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
			redirect('/all_books')
		else
			session[:failure] = "Login failed"
			redirect('/index')
		end
	end
end
