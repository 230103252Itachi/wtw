String getClothesRecommendation(double temp) {
  if (temp >= 25) return "Hot - t-shirt and shorts 😎";
  if (temp >= 15) return "Warm - hoodie or light jacket 🙂";
  if (temp >= 5) return "Cool - sweater or cardigan 🧣";
  return "Cold - warm jacket, gloves and hat 🥶";
}
