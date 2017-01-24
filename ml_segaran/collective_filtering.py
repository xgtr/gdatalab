

from math import sqrt

# A dictionary of movie critics and their ratings of a small
# set of movies
critics = {'Lisa Rose': {'Lady in the Water': 2.5,
                         'Snakes on a Plane': 3.5,
                         'Just My Luck': 3.0,
                         'Superman Returns': 3.5,
                         'You, Me and Dupree': 2.5,
                         'The Night Listener': 3.0},
           'Gene Seymour': {'Lady in the Water': 3.0,
                            'Snakes on a Plane': 3.5,
                            'Just My Luck': 1.5,
                            'Superman Returns': 5.0,
                            'The Night Listener': 3.0,
                            'You, Me and Dupree': 3.5},
           'Michael Phillips': {'Lady in the Water': 2.5,
                                'Snakes on a Plane': 3.0,
                                'Superman Returns': 3.5,
                                'The Night Listener': 4.0},
           'Claudia Puig': {'Snakes on a Plane': 3.5,
                            'Just My Luck': 3.0,
                            'The Night Listener': 4.5,
                            'Superman Returns': 4.0,
                            'You, Me and Dupree': 2.5},
           'Mick LaSalle': {'Lady in the Water': 3.0,
                            'Snakes on a Plane': 4.0,
                            'Just My Luck': 2.0,
                            'Superman Returns': 3.0,
                            'The Night Listener': 3.0,
                            'You, Me and Dupree': 2.0},
           'Jack Matthews': {'Lady in the Water': 3.0,
                             'Snakes on a Plane': 4.0,
                             'The Night Listener': 3.0,
                             'Superman Returns': 5.0,
                             'You, Me and Dupree': 3.5},
           'Toby': {'Snakes on a Plane': 4.5,
                    'You, Me and Dupree': 1.0,
                    'Superman Returns': 4.0},
           'pp1': {'Star Wars': 5.0,
                   'Whiplash': 4.0},
           'pp2': {'Star Wars': 2.0,
                   'Whiplash': 1.0},
           'pp3': {'Star Wars': 4.0,
                   'Whiplash': 3.0}}


# Returns a distance-based similarity score for person1 and person2
def sim_distance(prefs, person1, person2):
    """Euclidean distance between person1 and person2
    """
    sim = {}
    for item in prefs[person1]:
        if item in prefs[person2]:
            sim[item] = 1

    if len(sim) == 0:
        return 0

    distance = sum(
        [pow(prefs[person1][item] - prefs[person2][item], 2) for item in sim])
    return 1 / (1 + distance)


# Returns the Pearson correlation coefficient for p1 and p2
def sim_pearson(prefs, p1, p2):
    # Get the list of mutually rated items
    si = {}
    for item in prefs[p1]:
        if item in prefs[p2]:
            si[item] = 1

    # Find the number of elements
    n = len(si)
    # if they are no ratings in common, return 0
    if n == 0:
        return 0

    # Add up all the preferences
    sum1 = sum([prefs[p1][it] for it in si])
    sum2 = sum([prefs[p2][it] for it in si])

    # Sum up the squares
    sum1Sq = sum([pow(prefs[p1][it], 2) for it in si])
    sum2Sq = sum([pow(prefs[p2][it], 2) for it in si])

    # Sum up the products
    pSum = sum([prefs[p1][it] * prefs[p2][it] for it in si])

    # Calculate Pearson score
    num = pSum - (sum1 * sum2 / n)
    den = sqrt((sum1Sq - pow(sum1, 2) / n) * (sum2Sq - pow(sum2, 2) / n))

    if den == 0:
        return 0.0

    r = num / den
    return r

# from itertools import combinations
# sim=[(pair, sim_distance(critics, *pair))
#       for pair in combinations(critics, 2)]
# sorted(sim, key=lambda x: x[1], reverse=True)


def get_similar_critic(prefs, person, sim_func=sim_distance):
    """get a sorted similarity for person"""
    sim = [((person, p), sim_func(prefs, p, person)) for p in prefs]
    return sorted(sim, key=lambda x: x[1], reverse=True)


def top_match(prefs, person, n=5, sim_func=sim_pearson):
    scores = [(sim_func(prefs, other, person), other)
              for other in prefs if other != person]
    scores.sort()
    scores.reverse()
    return scores[:n]


import numpy as np
from collections import defaultdict


def get_recommendations(prefs, person, sim_func=sim_pearson):
    """Get a weighted average scores of every other user's rankings"""
    sim = {p: sim_func(prefs, person, p) for p in prefs if p != person}
    w_score = defaultdict(list)

    for p in prefs:
        if p == person or sim[p] <= 0:
            continue
        for movie, score in prefs[p].items():
            if movie in prefs[person]:
                continue
            print(p, movie, score)
            w_score[movie].append((sim[p], sim[p] * score))

    recom = {}
    for movie, score in w_score.items():
        nps = np.array(score)
        recom[movie] = nps.sum(axis=0)
    return recom


def transform_prefs(prefs):
    t_prefs = defaultdict(dict)
    for person, reviews in prefs.items():
        for movie, score in reviews.items():
            t_prefs[movie][person] = score
    return t_prefs
