def total(items):
    return sum(item["price"] for item in items)


print(total([{"price": 3}, {"price": 4}]))
