from random_word import RandomWords

r = RandomWords()


for i in range(500):
    # Generate two random words
    word1 = r.get_random_word()
    word2 = r.get_random_word()

    print(f"{word1}_{word2}")
