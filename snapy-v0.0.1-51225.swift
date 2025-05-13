import SwiftUI
import Combine

// MARK: - User Model
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var username: String
    var profilePicture: String /
    var friends: [UUID]
    var posts: [UUID]
    var bio: String

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Post Model
struct Post: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID 
    var content: String
    var timestamp: Date
    var likes: [UUID]
    var comments: [Comment]

    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID // ID of the user who posted the comment
    var text: String
    let timestamp: Date
}

// MARK: - Data Manager (Handles Data Persistence and Logic)
class DataManager: ObservableObject {
    @Published var users: [User] = []
    @Published var posts: [Post] = []
    @Published var currentUser: User? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading = false

    private let usersKey = "users"
    private let postsKey = "posts"
    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadUsers()
        loadPosts()
    }

    // MARK: - Load Data
    func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey) {
            do {
                let decodedUsers = try JSONDecoder().decode([User].self, from: data)
                users = decodedUsers
            } catch {
                errorMessage = "Failed to decode users: \(error.localizedDescription)"
            }
        }
    }

    func loadPosts() {
        if let data = UserDefaults.standard.data(forKey: postsKey) {
            do {
                let decodedPosts = try JSONDecoder().decode([Post].self, from: data)
                posts = decodedPosts
            } catch {
                errorMessage = "Failed to decode posts: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Save Data
    func saveUsers() {
        do {
            let encodedUsers = try JSONEncoder().encode(users)
            UserDefaults.standard.set(encodedUsers, forKey: usersKey)
        } catch {
            errorMessage = "Failed to encode users: \(error.localizedDescription)"
        }
    }

    func savePosts() {
        do {
            let encodedPosts = try JSONEncoder().encode(posts)
            UserDefaults.standard.set(encodedPosts, forKey: postsKey)
        } catch {
            errorMessage = "Failed to encode posts: \(error.localizedDescription)"
        }
    }

    // MARK: - User Management
    func signUp(username: String) {
        if users.contains(where: { $0.username == username }) {
            errorMessage = "Username already exists."
            return
        }
        let newUser = User(id: UUID(), username: username, profilePicture: "person.circle", friends: [], posts: [], bio: "")
        users.append(newUser)
        currentUser = newUser
        saveUsers()
    }

    func login(username: String) {
        if let user = users.first(where: { $0.username == username }) {
            currentUser = user
            saveUsers()
        } else {
            errorMessage = "User not found."
        }
    }

    func logout() {
        currentUser = nil
    }

    // MARK: - Post Management
    func createPost(content: String) {
        guard let user = currentUser else {
            errorMessage = "You must be logged in to create a post."
            return
        }
        let newPost = Post(id: UUID(), userId: user.id, content: content, timestamp: Date(), likes: [], comments: [])
        posts.append(newPost)
        users = users.map {
            var mutableUser = $0
            if mutableUser.id == user.id {
                mutableUser.posts.append(newPost.id)
            }
            return mutableUser
        }
        savePosts()
        saveUsers()
    }

    func likePost(post: Post) {
        guard let user = currentUser else {
            errorMessage = "You must be logged in to like a post."
            return
        }
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            if posts[index].likes.contains(user.id) {
                posts[index].likes.removeAll { $0 == user.id }
            } else {
                posts[index].likes.append(user.id)
            }
            savePosts()
        }
    }

    func addComment(post: Post, text: String) {
        guard let user = currentUser else {
            errorMessage = "You must be logged in to comment."
            return
        }
        let newComment = Comment(id: UUID(), userId: user.id, text: text, timestamp: Date())
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].comments.append(newComment)
            savePosts()
        }
    }

    // MARK: - Friend Management
     func addFriend(user: User) {
        guard let currentUser = currentUser else {
            errorMessage = "You must be logged in to add friends."
            return
        }

        // Prevent adding self
        if currentUser.id == user.id {
            errorMessage = "You can't add yourself as a friend."
            return
        }

        // Prevent duplicate friends
        if currentUser.friends.contains(user.id) {
            errorMessage = "You are already friends with this user."
            return
        }

        // Add friend to current user's list
        self.users = self.users.map {
            var mutableUser = $0
            if mutableUser.id == currentUser.id {
                mutableUser.friends.append(user.id)
            }
            return mutableUser
        }
        saveUsers()
    }

    func getFriends(for user: User) -> [User] {
        return users.filter { user.friends.contains($0.id) }
    }

    func getPosts(for user: User) -> [Post] {
        return posts.filter { $0.userId == user.id }
    }

    func getAllPosts() -> [Post] {
           // Sort posts by timestamp, newest first
           return posts.sorted(by: { $0.timestamp > $1.timestamp })
    }
    func getUser(by id: UUID) -> User? {
        return users.first { $0.id == id }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isLoggedIn: Bool // Use a binding to update the state in ContentView
    @State private var username: String = ""
    @State private var isShowingSignUp = false
    @State private var loginError: String?

    var body: some View {
        ZStack {
            // Background Color
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.95, green: 0.90, blue: 0.90), Color(red: 0.80, green: 0.88, blue: 0.92)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // App Logo (Styled)
                Text("Snapy")
                    .font(.system(size: 90, weight: .heavy, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .shadow(color: Color.gray.opacity(0.3), radius: 10, x: 5, y: 5)
                    .padding(.bottom, 60)

                // Tagline
                Text("Share Your Moments")
                    .font(.title3)
                    .foregroundColor(Color.gray)
                    .padding(.bottom, 80)

                // Username Text Field
                TextField("Username", text: $username)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(10)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .autocapitalization(.none)

                // Login Button (Glassmorphism)
                Button(action: {
                    if !username.isEmpty {
                        dataManager.login(username: username)
                        if dataManager.currentUser != nil {
                            isLoggedIn = true // Update the isLoggedIn state
                        } else {
                            loginError = dataManager.errorMessage
                        }
                    } else {
                        loginError = "Please enter username"
                    }
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 18)
                        .background(
                            // Glassmorphism effect
                            ZStack {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.white.opacity(0.2))
                                    .blur(radius: 10)
                            }
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 5, y: 5)
                }
                .padding(.top, 20)

                // Sign Up Button
                Button(action: {
                    isShowingSignUp = true
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .cornerRadius(15)
                }
                .padding(.top, 20)

                if let error = loginError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView(isLoggedIn: $isLoggedIn) // Pass the binding to SignUpView as well
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: DataManager
    @State private var username: String = ""
    @State private var signUpError: String?
    @Binding var isLoggedIn: Bool  // Add a binding to isLoggedIn

    var body: some View {
        VStack {
            Text("Sign Up")
                .font(.title)
                .padding()

            TextField("Username", text: $username)
                .padding()
                .background(Color.white.opacity(0.3))
                .cornerRadius(10)
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .autocapitalization(.none)

            Button(action: {
                if !username.isEmpty {
                    dataManager.signUp(username: username)
                    if dataManager.currentUser != nil {
                        isLoggedIn = true // Update the isLoggedIn state upon successful sign up
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        signUpError = dataManager.errorMessage
                    }
                } else {
                    signUpError = "Please enter username"
                }
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 18)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding(.top, 20)
            if let error = signUpError {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Post View
struct PostView: View {
    @EnvironmentObject var dataManager: DataManager
    let post: Post
    @State private var commentText: String = ""
    @State private var showComments = false

    var body: some View {
        VStack(alignment: .leading) {
            // Post Header
            HStack {
                if let user = dataManager.getUser(by: post.userId) {
                    Text(user.profilePicture) // Display profile picture
                        .font(.system(size: 30))
                    Text(user.username)
                        .font(.headline)
                    Spacer()
                    Text(post.timestamp.formatted()) // Show formatted date
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)

            // Post Content
            Text(post.content)
                .padding(.horizontal)

            // Post Actions
            HStack {
                Button(action: {
                    dataManager.likePost(post: post)
                }) {
                    Image(systemName: post.likes.contains(dataManager.currentUser?.id ?? UUID()) ? "heart.fill" : "heart")
                    Text("\(post.likes.count)")
                }
                .padding(.horizontal)

                Button(action: {
                    showComments.toggle()
                }) {
                    Image(systemName: "message")
                    Text("\(post.comments.count) Comments")
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding(.vertical, 8)
            .sheet(isPresented: $showComments) {
                CommentsView(post: post, onComment: {
                    dataManager.addComment(post: post, text: commentText)
                    commentText = ""
                })
            }
            Divider()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Comments View
struct CommentsView: View {
    let post: Post
    @State private var commentText: String = ""
    var onComment: () -> Void
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack {
            Text("Comments")
                .font(.title)
                .padding()
            ScrollView {
                ForEach(post.comments) { comment in
                    HStack {
                        if let user = dataManager.getUser(by: comment.userId){
                            Text(user.profilePicture)
                                .font(.system(size: 20))
                            Text(user.username)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(comment.text)
                                .padding(.horizontal, 8)
                            Spacer()
                            Text(comment.timestamp.formatted())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                    }
                    .padding(.horizontal)
                    Divider()
                }
            }
            HStack {
                TextField("Add a comment...", text: $commentText)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(10)
                Button(action: {
                    if !commentText.isEmpty{
                        onComment()
                    }

                }) {
                    Text("Post")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}

// MARK: - Feed View
struct FeedView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var newPostContent: String = ""

    var body: some View {
        ScrollView {
            VStack {
                // New Post Input
                HStack {
                    TextField("What's on your mind?", text: $newPostContent)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(10)
                    Button(action: {
                        if !newPostContent.isEmpty {
                            dataManager.createPost(content: newPostContent)
                            newPostContent = "" // Clear input field
                        }
                    }) {
                        Text("Post")
                            .foregroundColor(.blue)
                    }
                }
                .padding()

                // Display Posts
                ForEach(dataManager.getAllPosts()) { post in
                    PostView(post: post)
                }
            }
        }
        .background(Color(red: 0.95, green: 0.90, blue: 0.90))
        .ignoresSafeArea()
        .navigationTitle("Feed")
    }
}

// MARK: - Friends View
struct FriendsView: View {
    @EnvironmentObject var dataManager: DataManager
    let user: User // The user whose friends we are displaying

    var body: some View {
        ScrollView {
            VStack {
                Text("\(user.username)'s Friends")
                    .font(.title2)
                    .padding()

                let friends = dataManager.getFriends(for: user)
                if friends.isEmpty {
                    Text("No friends yet.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(friends) { friend in
                        HStack {
                            Text(friend.profilePicture) // Display profile picture
                                .font(.system(size: 30))
                            Text(friend.username)
                                .font(.headline)
                            Spacer()
                            Button("Add Friend"){ //You can only add friends from other people's friend list
                                dataManager.addFriend(user: friend)
                            }
                        }
                        .padding()
                        Divider()
                    }
                }
            }
        }
        .background(Color(red: 0.95, green: 0.90, blue: 0.90))
        .ignoresSafeArea()
        .navigationTitle("Friends")
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isEditing = false
    @State private var newBio: String = ""
    @State private var selectedUser: User?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // User Info
                if let user = dataManager.currentUser {
                    HStack {
                        Text(user.profilePicture) // Display  profile picture
                            .font(.system(size: 80))
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .font(.title)
                            Text("Posts: \(user.posts.count)")
                                .font(.subheadline)
                            Text("Friends: \(user.friends.count)")
                                .font(.subheadline)
                        }
                        Spacer()
                        Button(action: {
                            isEditing = true
                            newBio = user.bio
                        }) {
                            Text(isEditing ? "Save" : "Edit")
                        }
                        .sheet(isPresented: $isEditing) {
                            EditBioView(bio: $newBio, onSave: {
                                dataManager.currentUser?.bio = newBio
                                dataManager.saveUsers()
                                isEditing = false
                            })
                        }
                    }
                    .padding()

                    Text("Bio")
                        .font(.headline)
                        .padding(.leading)
                    Text(user.bio)
                        .padding(.horizontal)

                    Text("Posts")
                        .font(.title2)
                        .padding(.leading)

                    // User's Posts
                    ForEach(dataManager.getPosts(for: user)) { post in
                        PostView(post: post)
                    }
                    
                    Text("Friends")
                        .font(.title2)
                        .padding(.leading)
                    
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack{
                            ForEach(dataManager.getFriends(for: user)){ friend in
                                Button(action: {
                                    selectedUser = friend
                                }){
                                    VStack{
                                        Text(friend.profilePicture)
                                            .font(.system(size: 50))
                                        Text(friend.username)
                                            .font(.caption)
                                    }
                                }
                                .sheet(item: $selectedUser){ user in
                                    FriendsView(user: user)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    

                } else {
                    Text("No user logged in.")
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.95, green: 0.90, blue: 0.90))
        .ignoresSafeArea()
        .navigationTitle("Profile")
    }
}

// MARK: - Edit Bio View
struct EditBioView: View {
    @Binding var bio: String
    var onSave: () -> Void

    var body: some View {
        VStack {
            Text("Edit Bio")
                .font(.title)
                .padding()
            TextEditor(text: $bio)
                .frame(height: 200)
                .padding()
                .background(Color.white.opacity(0.3))
                .cornerRadius(10)
            Button(action: onSave) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 18)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject var dataManager = DataManager()
    @State private var selectedTab = 0
    @State private var showingFriends = false
    @State private var isLoggedIn = false

    var body: some View {
        NavigationView {
            VStack {
                if dataManager.currentUser != nil {
                    // Tab Bar
                    HStack {
                        // Feed Tab
                        Button(action: { selectedTab = 0 }) {
                            VStack {
                                Text("Feed")
                                    .font(.system(size: 12))
                                    .foregroundColor(selectedTab == 0 ? .blue : .gray)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Friends Tab
                        Button(action: { selectedTab = 1 }) {
                            VStack {
                                Text("Friends")
                                    .font(.system(size: 12))
                                    .foregroundColor(selectedTab == 1 ? .blue : .gray)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Profile Tab
                        Button(action: { selectedTab = 2 }) {
                            VStack {
                                Text("Profile")
                                    .font(.system(size: 12))
                                    .foregroundColor(selectedTab == 2 ? .blue : .gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                    .background(Color.white.opacity(0.8))
                    .shadow(radius: 2)
                    .padding(.bottom, 8)

                    // Main Content Area
                    switch selectedTab {
                    case 0:
                        FeedView()
                    case 1:
                        if let user = dataManager.currentUser{
                            FriendsView(user: user)
                        }
                        else{
                            Text("No User")
                        }

                    case 2:
                        ProfileView()
                    default:
                        Text("Unknown Tab")
                    }
                } else {
                    // Show Login Screen
                    LoginView(isLoggedIn: $isLoggedIn) // Pass the binding here
                }
            }
            .navigationBarItems(
                leading: dataManager.currentUser == nil ? nil :  Button("Logout") {
                    dataManager.logout()
                    isLoggedIn = false
                    selectedTab = 0
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .environmentObject(dataManager) // Set the DataManager as an environment object
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// This is the entry point of the app
@main
struct SnapyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
