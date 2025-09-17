// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UserRegistry.sol";

/**
 * @title ContentManager
 * @dev Advanced content management with complex data relationships
 *
 * Features:
 * - Post creation and management
 * - Comment threads and discussions
 * - Content categorization and tagging
 * - Vote and rating systems
 * - Content moderation and reporting
 * - Efficient content retrieval and pagination
 */

contract ContentManager {
    // ======================
    // DATA STRUCTURES
    // ======================

    struct Post {
        uint256 id;
        address author;
        string title;
        string content;
        string[] tags;
        uint256 categoryId;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 likesCount;
        uint256 dislikesCount;
        uint256 commentsCount;
        uint256 viewsCount;
        bool isPublished;
        bool isPinned;
        mapping(address => bool) likedBy;
        mapping(address => bool) dislikedBy;
        mapping(string => string) metadata; // key => value
    }

    struct Comment {
        uint256 id;
        uint256 postId;
        uint256 parentCommentId; // 0 for top-level comments
        address author;
        string content;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 likesCount;
        uint256 repliesCount;
        bool isDeleted;
        mapping(address => bool) likedBy;
    }

    struct Category {
        uint256 id;
        string name;
        string description;
        address creator;
        uint256 postsCount;
        bool isActive;
        mapping(string => bool) allowedTags;
        string[] tagsList;
    }

    // Packed struct for gas efficiency
    struct PostFlags {
        bool isPublished;
        bool isPinned;
        bool isLocked;
        bool isNSFW;
        uint8 difficultyLevel; // 0-255
        uint16 readTime; // estimated minutes
        uint32 lastActivityTime;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    UserRegistry public immutable userRegistry;

    // Content storage
    mapping(uint256 => Post) public posts;
    mapping(uint256 => Comment) public comments;
    mapping(uint256 => Category) public categories;
    mapping(uint256 => PostFlags) public postFlags;

    // Enumeration and indexing
    uint256[] public allPostIds;
    uint256[] public allCommentIds;
    uint256[] public allCategoryIds;

    mapping(uint256 => uint256) public postIndices;
    mapping(uint256 => uint256) public commentIndices;
    mapping(uint256 => uint256) public categoryIndices;

    // Author indexing
    mapping(address => uint256[]) public postsByAuthor;
    mapping(address => uint256[]) public commentsByAuthor;

    // Category and tag indexing
    mapping(uint256 => uint256[]) public postsByCategory;
    mapping(string => uint256[]) public postsByTag;
    mapping(string => bool) public tagExists;
    string[] public allTags;

    // Comment threading
    mapping(uint256 => uint256[]) public commentsByPost;
    mapping(uint256 => uint256[]) public repliesByComment;

    // Trending and discovery
    mapping(uint256 => uint256[]) public dailyPosts; // day => post IDs
    mapping(uint256 => uint256[]) public weeklyTrending;
    mapping(address => uint256[]) public userReadHistory;

    // Vote tracking
    mapping(address => mapping(uint256 => bool)) public hasVotedOnPost;
    mapping(address => mapping(uint256 => bool)) public hasVotedOnComment;

    // Content moderation
    mapping(uint256 => uint256) public postReports;
    mapping(uint256 => uint256) public commentReports;
    mapping(address => bool) public isModerator;

    // Counters
    uint256 public nextPostId = 1;
    uint256 public nextCommentId = 1;
    uint256 public nextCategoryId = 1;

    // Constants
    uint256 public constant MAX_TITLE_LENGTH = 200;
    uint256 public constant MAX_CONTENT_LENGTH = 10000;
    uint256 public constant MAX_TAGS_PER_POST = 10;
    uint256 public constant TRENDING_THRESHOLD = 10;

    // ======================
    // EVENTS
    // ======================

    event PostCreated(
        uint256 indexed postId,
        address indexed author,
        uint256 categoryId
    );
    event PostUpdated(uint256 indexed postId, address indexed author);
    event PostDeleted(uint256 indexed postId, address indexed author);
    event CommentCreated(
        uint256 indexed commentId,
        uint256 indexed postId,
        address indexed author
    );
    event PostLiked(uint256 indexed postId, address indexed user, bool isLike);
    event CommentLiked(uint256 indexed commentId, address indexed user);
    event CategoryCreated(
        uint256 indexed categoryId,
        string name,
        address indexed creator
    );
    event PostViewed(uint256 indexed postId, address indexed viewer);

    // ======================
    // MODIFIERS
    // ======================

    modifier onlyRegisteredUser() {
        require(userRegistry.isRegistered(msg.sender), "User not registered");
        _;
    }

    modifier onlyPostAuthor(uint256 _postId) {
        require(posts[_postId].author == msg.sender, "Not post author");
        _;
    }

    modifier onlyCommentAuthor(uint256 _commentId) {
        require(
            comments[_commentId].author == msg.sender,
            "Not comment author"
        );
        _;
    }

    modifier postExists(uint256 _postId) {
        require(_postId < nextPostId && _postId > 0, "Post does not exist");
        _;
    }

    modifier commentExists(uint256 _commentId) {
        require(
            _commentId < nextCommentId && _commentId > 0,
            "Comment does not exist"
        );
        _;
    }

    modifier onlyModerator() {
        require(isModerator[msg.sender], "Not a moderator");
        _;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(address _userRegistry) {
        userRegistry = UserRegistry(_userRegistry);
        isModerator[msg.sender] = true; // Contract deployer is initial moderator
    }

    // ======================
    // POST MANAGEMENT
    // ======================

    /**
     * @dev Create a new post
     */
    function createPost(
        string memory _title,
        string memory _content,
        uint256 _categoryId,
        string[] memory _tags,
        uint8 _difficultyLevel,
        uint16 _readTime
    ) external onlyRegisteredUser returns (uint256 postId) {
        require(
            bytes(_title).length > 0 &&
                bytes(_title).length <= MAX_TITLE_LENGTH,
            "Invalid title"
        );
        require(
            bytes(_content).length > 0 &&
                bytes(_content).length <= MAX_CONTENT_LENGTH,
            "Invalid content"
        );
        require(_tags.length <= MAX_TAGS_PER_POST, "Too many tags");
        require(_categoryExists(_categoryId), "Category does not exist");

        postId = nextPostId++;

        // Initialize post
        Post storage post = posts[postId];
        post.id = postId;
        post.author = msg.sender;
        post.title = _title;
        post.content = _content;
        post.categoryId = _categoryId;
        post.createdAt = block.timestamp;
        post.updatedAt = block.timestamp;
        post.isPublished = true;

        // Set tags
        for (uint256 i = 0; i < _tags.length; i++) {
            post.tags.push(_tags[i]);
            postsByTag[_tags[i]].push(postId);

            if (!tagExists[_tags[i]]) {
                tagExists[_tags[i]] = true;
                allTags.push(_tags[i]);
            }
        }

        // Set flags
        postFlags[postId] = PostFlags({
            isPublished: true,
            isPinned: false,
            isLocked: false,
            isNSFW: false,
            difficultyLevel: _difficultyLevel,
            readTime: _readTime,
            lastActivityTime: uint32(block.timestamp)
        });

        // Update indices
        postIndices[postId] = allPostIds.length;
        allPostIds.push(postId);
        postsByAuthor[msg.sender].push(postId);
        postsByCategory[_categoryId].push(postId);

        // Track daily posts
        uint256 today = block.timestamp / 1 days;
        dailyPosts[today].push(postId);

        // Update category post count
        categories[_categoryId].postsCount++;

        // Update user stats
        userRegistry.updateUserStats(msg.sender, "post", 1);

        emit PostCreated(postId, msg.sender, _categoryId);
    }

    /**
     * @dev Update an existing post
     */
    function updatePost(
        uint256 _postId,
        string memory _title,
        string memory _content,
        string[] memory _tags
    ) external postExists(_postId) onlyPostAuthor(_postId) {
        require(
            bytes(_title).length > 0 &&
                bytes(_title).length <= MAX_TITLE_LENGTH,
            "Invalid title"
        );
        require(
            bytes(_content).length > 0 &&
                bytes(_content).length <= MAX_CONTENT_LENGTH,
            "Invalid content"
        );
        require(_tags.length <= MAX_TAGS_PER_POST, "Too many tags");

        Post storage post = posts[_postId];

        // Remove old tags
        for (uint256 i = 0; i < post.tags.length; i++) {
            _removePostFromTag(post.tags[i], _postId);
        }
        delete post.tags;

        // Update post data
        post.title = _title;
        post.content = _content;
        post.updatedAt = block.timestamp;

        // Add new tags
        for (uint256 i = 0; i < _tags.length; i++) {
            post.tags.push(_tags[i]);
            postsByTag[_tags[i]].push(_postId);

            if (!tagExists[_tags[i]]) {
                tagExists[_tags[i]] = true;
                allTags.push(_tags[i]);
            }
        }

        postFlags[_postId].lastActivityTime = uint32(block.timestamp);

        emit PostUpdated(_postId, msg.sender);
    }

    /**
     * @dev Delete a post (soft delete)
     */
    function deletePost(
        uint256 _postId
    ) external postExists(_postId) onlyPostAuthor(_postId) {
        posts[_postId].isPublished = false;
        postFlags[_postId].isPublished = false;

        emit PostDeleted(_postId, msg.sender);
    }

    // ======================
    // COMMENT MANAGEMENT
    // ======================

    /**
     * @dev Create a comment on a post
     */
    function createComment(
        uint256 _postId,
        uint256 _parentCommentId,
        string memory _content
    )
        external
        postExists(_postId)
        onlyRegisteredUser
        returns (uint256 commentId)
    {
        require(bytes(_content).length > 0, "Content cannot be empty");
        require(posts[_postId].isPublished, "Post not published");

        if (_parentCommentId > 0) {
            require(
                _commentId < nextCommentId,
                "Parent comment does not exist"
            );
            require(
                comments[_parentCommentId].postId == _postId,
                "Parent comment not in same post"
            );
        }

        commentId = nextCommentId++;

        // Initialize comment
        Comment storage comment = comments[commentId];
        comment.id = commentId;
        comment.postId = _postId;
        comment.parentCommentId = _parentCommentId;
        comment.author = msg.sender;
        comment.content = _content;
        comment.createdAt = block.timestamp;
        comment.updatedAt = block.timestamp;

        // Update indices
        commentIndices[commentId] = allCommentIds.length;
        allCommentIds.push(commentId);
        commentsByAuthor[msg.sender].push(commentId);
        commentsByPost[_postId].push(commentId);

        // Update parent comment if this is a reply
        if (_parentCommentId > 0) {
            repliesByComment[_parentCommentId].push(commentId);
            comments[_parentCommentId].repliesCount++;
        }

        // Update counters
        posts[_postId].commentsCount++;
        postFlags[_postId].lastActivityTime = uint32(block.timestamp);

        // Update user stats
        userRegistry.updateUserStats(msg.sender, "comment", 1);

        emit CommentCreated(commentId, _postId, msg.sender);
    }

    /**
     * @dev Update a comment
     */
    function updateComment(
        uint256 _commentId,
        string memory _content
    ) external commentExists(_commentId) onlyCommentAuthor(_commentId) {
        require(bytes(_content).length > 0, "Content cannot be empty");
        require(!comments[_commentId].isDeleted, "Comment is deleted");

        comments[_commentId].content = _content;
        comments[_commentId].updatedAt = block.timestamp;
    }

    /**
     * @dev Delete a comment (soft delete)
     */
    function deleteComment(
        uint256 _commentId
    ) external commentExists(_commentId) onlyCommentAuthor(_commentId) {
        comments[_commentId].isDeleted = true;
        posts[comments[_commentId].postId].commentsCount--;
    }

    // ======================
    // VOTING SYSTEM
    // ======================

    /**
     * @dev Like or dislike a post
     */
    function voteOnPost(
        uint256 _postId,
        bool _isLike
    ) external postExists(_postId) onlyRegisteredUser {
        Post storage post = posts[_postId];
        require(post.author != msg.sender, "Cannot vote on own post");

        // Remove previous vote if exists
        if (post.likedBy[msg.sender]) {
            post.likedBy[msg.sender] = false;
            post.likesCount--;
        }
        if (post.dislikedBy[msg.sender]) {
            post.dislikedBy[msg.sender] = false;
            post.dislikesCount--;
        }

        // Add new vote
        if (_isLike) {
            post.likedBy[msg.sender] = true;
            post.likesCount++;
        } else {
            post.dislikedBy[msg.sender] = true;
            post.dislikesCount++;
        }

        hasVotedOnPost[msg.sender][_postId] = true;
        postFlags[_postId].lastActivityTime = uint32(block.timestamp);

        emit PostLiked(_postId, msg.sender, _isLike);
    }

    /**
     * @dev Like a comment
     */
    function likeComment(
        uint256 _commentId
    ) external commentExists(_commentId) onlyRegisteredUser {
        Comment storage comment = comments[_commentId];
        require(comment.author != msg.sender, "Cannot like own comment");
        require(!comment.likedBy[msg.sender], "Already liked");

        comment.likedBy[msg.sender] = true;
        comment.likesCount++;
        hasVotedOnComment[msg.sender][_commentId] = true;

        emit CommentLiked(_commentId, msg.sender);
    }

    // ======================
    // CATEGORY MANAGEMENT
    // ======================

    /**
     * @dev Create a new category
     */
    function createCategory(
        string memory _name,
        string memory _description,
        string[] memory _allowedTags
    ) external onlyModerator returns (uint256 categoryId) {
        require(bytes(_name).length > 0, "Name cannot be empty");

        categoryId = nextCategoryId++;

        Category storage category = categories[categoryId];
        category.id = categoryId;
        category.name = _name;
        category.description = _description;
        category.creator = msg.sender;
        category.isActive = true;

        // Set allowed tags
        for (uint256 i = 0; i < _allowedTags.length; i++) {
            category.allowedTags[_allowedTags[i]] = true;
            category.tagsList.push(_allowedTags[i]);
        }

        categoryIndices[categoryId] = allCategoryIds.length;
        allCategoryIds.push(categoryId);

        emit CategoryCreated(categoryId, _name, msg.sender);
    }

    // ======================
    // CONTENT DISCOVERY
    // ======================

    /**
     * @dev Record a post view
     */
    function viewPost(
        uint256 _postId
    ) external postExists(_postId) onlyRegisteredUser {
        posts[_postId].viewsCount++;
        userReadHistory[msg.sender].push(_postId);

        emit PostViewed(_postId, msg.sender);
    }

    /**
     * @dev Get trending posts based on recent activity
     */
    function getTrendingPosts(
        uint256 _limit
    ) external view returns (uint256[] memory trendingPosts) {
        uint256 count = 0;
        uint256[] memory tempPosts = new uint256[](allPostIds.length);

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < allPostIds.length && count < _limit; i++) {
            uint256 postId = allPostIds[i];
            Post storage post = posts[postId];

            if (!post.isPublished) continue;

            // Calculate trending score based on likes, comments, and recency
            uint256 age = (currentTime - post.createdAt) / 1 hours;
            if (age == 0) age = 1; // Prevent division by zero

            uint256 score = (post.likesCount *
                3 +
                post.commentsCount *
                2 +
                post.viewsCount) / age;

            if (score >= TRENDING_THRESHOLD) {
                tempPosts[count] = postId;
                count++;
            }
        }

        trendingPosts = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            trendingPosts[i] = tempPosts[i];
        }
    }

    /**
     * @dev Get posts by author with pagination
     */
    function getPostsByAuthor(
        address _author,
        uint256 _start,
        uint256 _limit
    ) external view returns (uint256[] memory postIds, bool hasMore) {
        uint256[] storage authorPosts = postsByAuthor[_author];

        if (_start >= authorPosts.length) {
            return (new uint256[](0), false);
        }

        uint256 end = _start + _limit;
        if (end > authorPosts.length) {
            end = authorPosts.length;
        }

        uint256 length = end - _start;
        postIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            postIds[i] = authorPosts[_start + i];
        }

        hasMore = end < authorPosts.length;
    }

    /**
     * @dev Get posts by category with pagination
     */
    function getPostsByCategory(
        uint256 _categoryId,
        uint256 _start,
        uint256 _limit
    ) external view returns (uint256[] memory postIds, bool hasMore) {
        uint256[] storage categoryPosts = postsByCategory[_categoryId];

        if (_start >= categoryPosts.length) {
            return (new uint256[](0), false);
        }

        uint256 end = _start + _limit;
        if (end > categoryPosts.length) {
            end = categoryPosts.length;
        }

        uint256 length = end - _start;
        postIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            postIds[i] = categoryPosts[_start + i];
        }

        hasMore = end < categoryPosts.length;
    }

    /**
     * @dev Get posts by tag
     */
    function getPostsByTag(
        string memory _tag
    ) external view returns (uint256[] memory) {
        return postsByTag[_tag];
    }

    /**
     * @dev Get comments for a post with pagination
     */
    function getCommentsByPost(
        uint256 _postId,
        uint256 _start,
        uint256 _limit
    ) external view returns (uint256[] memory commentIds, bool hasMore) {
        uint256[] storage postComments = commentsByPost[_postId];

        if (_start >= postComments.length) {
            return (new uint256[](0), false);
        }

        uint256 end = _start + _limit;
        if (end > postComments.length) {
            end = postComments.length;
        }

        uint256 length = end - _start;
        commentIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            commentIds[i] = postComments[_start + i];
        }

        hasMore = end < postComments.length;
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function _categoryExists(uint256 _categoryId) internal view returns (bool) {
        return
            _categoryId < nextCategoryId &&
            _categoryId > 0 &&
            categories[_categoryId].isActive;
    }

    function _removePostFromTag(string memory _tag, uint256 _postId) internal {
        uint256[] storage tagPosts = postsByTag[_tag];
        for (uint256 i = 0; i < tagPosts.length; i++) {
            if (tagPosts[i] == _postId) {
                tagPosts[i] = tagPosts[tagPosts.length - 1];
                tagPosts.pop();
                break;
            }
        }
    }

    // Getters
    function getTotalPosts() external view returns (uint256) {
        return allPostIds.length;
    }

    function getTotalComments() external view returns (uint256) {
        return allCommentIds.length;
    }

    function getTotalCategories() external view returns (uint256) {
        return allCategoryIds.length;
    }

    function getAllTags() external view returns (string[] memory) {
        return allTags;
    }
}

/**
 * 🧠 KEY LEARNING POINTS:
 *
 * 1. COMPLEX RELATIONSHIPS:
 *    - Posts, comments, categories, and tags interconnected
 *    - Parent-child relationships for comment threads
 *    - Many-to-many relationships (posts-tags)
 *    - One-to-many relationships (author-posts)
 *
 * 2. EFFICIENT INDEXING:
 *    - Multiple indexing strategies for different queries
 *    - Category and tag-based organization
 *    - Author-based content retrieval
 *    - Time-based trending algorithms
 *
 * 3. VOTING AND ENGAGEMENT:
 *    - Like/dislike system with vote tracking
 *    - Comment threading and replies
 *    - View counting and engagement metrics
 *    - Trending calculation based on multiple factors
 *
 * 4. MODERATION AND ADMINISTRATION:
 *    - Soft delete for content management
 *    - Moderator roles and permissions
 *    - Content reporting and flagging
 *    - Category management system
 *
 * ⚠️ PRODUCTION CONSIDERATIONS:
 * - Implement proper access controls
 * - Add content moderation tools
 * - Consider gas costs for complex operations
 * - Use events for off-chain indexing
 */
