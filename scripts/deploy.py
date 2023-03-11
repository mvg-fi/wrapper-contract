from ape import accounts, project

def main():
  tester = accounts.load("tester")
  contract = project.MiniumWrapper.deploy(tester, sender=tester, max_priority_fee=5 * 10**7, gas_price=5 * 10**7)
  print('deployed at:', contract)