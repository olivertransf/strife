import type { CareerCard, Decks, HouseCard, KeepCard, MoneyEffect } from "./types";

function career(
  id: string,
  kind: CareerCard["kind"],
  name: string,
  salary: number,
): CareerCard {
  return { id, kind, name, salary };
}

function house(
  id: string,
  name: string,
  cost: number,
  redSale: number,
  blackSale: number,
): HouseCard {
  return { id, kind: "house", name, cost, redSale, blackSale };
}

function keep(
  kind: KeepCard["kind"],
  id: string,
  name: string,
  text: string,
  effect: MoneyEffect,
): KeepCard {
  return { id, kind, name, text, effect };
}

export function standardDecks(): Decks {
  return {
    career: [
      career("career-driver", "career", "Route driver", 20),
      career("career-mail", "career", "Mail carrier", 30),
      career("career-cook", "career", "Line cook", 30),
      career("career-mechanic", "career", "Mechanic", 40),
      career("career-teacher", "career", "Teacher", 40),
      career("career-designer", "career", "Studio designer", 40),
      career("career-nurse", "career", "Clinic nurse", 50),
      career("career-sales", "career", "Sales lead", 50),
    ],
    collegeCareer: [
      career("college-professor", "collegeCareer", "Professor", 60),
      career("college-architect", "collegeCareer", "Architect", 70),
      career("college-pilot", "collegeCareer", "Airline pilot", 70),
      career("college-counsel", "collegeCareer", "Counsel", 80),
      career("college-scientist", "collegeCareer", "Research scientist", 80),
      career("college-engineer", "collegeCareer", "Engineer", 90),
      career("college-surgeon", "collegeCareer", "Surgeon", 100),
      career("college-director", "collegeCareer", "Creative director", 100),
    ],
    house: [
      house("house-cottage", "Cottage", 80, 120, 60),
      house("house-bungalow", "Bungalow", 120, 180, 80),
      house("house-loft", "Loft", 140, 160, 200),
      house("house-townhouse", "Townhouse", 160, 200, 140),
      house("house-lodge", "Lodge", 180, 260, 100),
      house("house-suburban", "Suburban", 200, 280, 150),
      house("house-villa", "Villa", 240, 320, 180),
      house("house-estate", "Estate", 300, 400, 220),
    ],
    action: [
      keep("action", "action-birthday", "Birthday cash", "The bank pays you 50K.", {
        type: "bankPays",
        amount: 50,
      }),
      keep("action", "action-tax", "Tax bill", "Pay the bank 40K.", {
        type: "bankCharges",
        amount: 40,
      }),
      keep("action", "action-friends", "Friends chip in", "Each other player pays you 20K.", {
        type: "eachOtherPaysYou",
        amount: 20,
      }),
      keep("action", "action-round", "You buy the round", "Pay each other player 10K.", {
        type: "youPayEach",
        amount: 10,
      }),
      keep("action", "action-bonus", "Yearly bonus", "The bank pays you 80K.", {
        type: "bankPays",
        amount: 80,
      }),
      keep("action", "action-repair", "Car repair", "Pay the bank 30K.", {
        type: "bankCharges",
        amount: 30,
      }),
      keep("action", "action-wallet", "Found wallet", "The bank pays you 20K.", {
        type: "bankPays",
        amount: 20,
      }),
      keep("action", "action-charity", "Charity drive", "Pay each other player 20K.", {
        type: "youPayEach",
        amount: 20,
      }),
      keep("action", "action-inheritance", "Inheritance", "The bank pays you 100K.", {
        type: "bankPays",
        amount: 100,
      }),
      keep("action", "action-fine", "City fine", "Pay the bank 50K.", {
        type: "bankCharges",
        amount: 50,
      }),
      keep("action", "action-side", "Side job", "The bank pays you 40K.", {
        type: "bankPays",
        amount: 40,
      }),
      keep("action", "action-dinner", "Dinner out", "Pay each other player 10K.", {
        type: "youPayEach",
        amount: 10,
      }),
      keep("action", "action-refund", "Refund", "The bank pays you 30K.", {
        type: "bankPays",
        amount: 30,
      }),
      keep("action", "action-storm", "Storm damage", "Pay the bank 60K.", {
        type: "bankCharges",
        amount: 60,
      }),
      keep("action", "action-tips", "Tip jar", "Each other player pays you 10K.", {
        type: "eachOtherPaysYou",
        amount: 10,
      }),
      keep("action", "action-prize", "Local prize", "The bank pays you 70K.", {
        type: "bankPays",
        amount: 70,
      }),
    ],
    pet: [
      keep("pet", "pet-reward", "Lost-dog reward", "The bank pays you 20K.", {
        type: "bankPays",
        amount: 20,
      }),
      keep("pet", "pet-vet", "Vet bill", "Pay the bank 30K.", {
        type: "bankCharges",
        amount: 30,
      }),
      keep("pet", "pet-show", "Pet show", "The bank pays you 40K.", {
        type: "bankPays",
        amount: 40,
      }),
      keep("pet", "pet-fee", "Adoption fee", "Pay the bank 20K.", {
        type: "bankCharges",
        amount: 20,
      }),
      keep("pet", "pet-sit", "Neighbor sits", "Each other player pays you 10K.", {
        type: "eachOtherPaysYou",
        amount: 10,
      }),
      keep("pet", "pet-party", "Pet party", "Pay each other player 10K.", {
        type: "youPayEach",
        amount: 10,
      }),
      keep("pet", "pet-collar", "Found collar", "The bank pays you 10K.", {
        type: "bankPays",
        amount: 10,
      }),
      keep("pet", "pet-training", "Training class", "Pay the bank 20K.", {
        type: "bankCharges",
        amount: 20,
      }),
    ],
  };
}
