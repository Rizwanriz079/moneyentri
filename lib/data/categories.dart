/// Static catalogues: transaction categories, payment methods, loan and bill
/// types. Icons are Ionicons names resolved by `appIcon()`.
library;

class Category {
  const Category(this.id, this.name, this.icon, this.color, this.type);
  final String id, name, icon, color, type;
}

const expenseCategories = [
  Category('food', 'Food & Dining', 'restaurant', '#F97316', 'expense'),
  Category('groceries', 'Groceries', 'cart', '#84CC16', 'expense'),
  Category('transport', 'Transport', 'car', '#0EA5E9', 'expense'),
  Category('shopping', 'Shopping', 'bag-handle', '#EC4899', 'expense'),
  Category('bills', 'Bills & Utilities', 'flash', '#EAB308', 'expense'),
  Category('rent', 'Rent', 'home', '#8B5CF6', 'expense'),
  Category('emi', 'EMI & Loans', 'card', '#EF4444', 'expense'),
  Category('subscriptions', 'Subscriptions', 'repeat', '#6366F1', 'expense'),
  Category('insurance', 'Insurance', 'shield-checkmark', '#14B8A6', 'expense'),
  Category('health', 'Health', 'medkit', '#F43F5E', 'expense'),
  Category('entertainment', 'Entertainment', 'film', '#A855F7', 'expense'),
  Category('education', 'Education', 'school', '#3B82F6', 'expense'),
  Category('travel', 'Travel', 'airplane', '#06B6D4', 'expense'),
  Category('personal', 'Personal Care', 'sparkles', '#D946EF', 'expense'),
  Category('gifts', 'Gifts', 'gift', '#F59E0B', 'expense'),
  Category('other', 'Other', 'ellipsis-horizontal', '#64748B', 'expense'),
];

const incomeCategories = [
  Category('salary', 'Salary', 'briefcase', '#16A34A', 'income'),
  Category('business', 'Business', 'storefront', '#059669', 'income'),
  Category('freelance', 'Freelance', 'laptop', '#0D9488', 'income'),
  Category('investments', 'Investments', 'trending-up', '#22C55E', 'income'),
  Category('rental', 'Rental Income', 'key', '#10B981', 'income'),
  Category('refund', 'Refund', 'return-down-back', '#65A30D', 'income'),
  Category('gift_in', 'Gift', 'gift', '#4ADE80', 'income'),
  Category('other_in', 'Other', 'ellipsis-horizontal', '#64748B', 'income'),
];

const _fallback = Category('other', 'Other', 'ellipsis-horizontal', '#64748B', 'expense');

Category getCategory(String id) {
  for (final c in expenseCategories) {
    if (c.id == id) return c;
  }
  for (final c in incomeCategories) {
    if (c.id == id) return c;
  }
  return _fallback;
}

List<Category> categoriesFor(String type) => type == 'income' ? incomeCategories : expenseCategories;

class PaymentMethodInfo {
  const PaymentMethodInfo(this.id, this.name, this.icon);
  final String id, name, icon;
}

const paymentMethods = [
  PaymentMethodInfo('cash', 'Cash', 'cash-outline'),
  PaymentMethodInfo('upi', 'UPI', 'phone-portrait-outline'),
  PaymentMethodInfo('card', 'Card', 'card-outline'),
  PaymentMethodInfo('bank', 'Bank', 'business-outline'),
];

String methodName(String id) => paymentMethods.firstWhere((m) => m.id == id, orElse: () => PaymentMethodInfo(id, id, '')).name;

class TypeInfo {
  const TypeInfo(this.id, this.name, this.icon, this.color, [this.expense = 'other']);
  final String id, name, icon, color;

  /// Expense category used when a bill of this type is paid.
  final String expense;
}

const loanTypes = [
  TypeInfo('car', 'Car Loan', 'car-sport', '#0EA5E9'),
  TypeInfo('personal', 'Personal Loan', 'person', '#8B5CF6'),
  TypeInfo('gold', 'Gold Loan', 'diamond', '#EAB308'),
  TypeInfo('home', 'Home Loan', 'home', '#F97316'),
  TypeInfo('education', 'Education Loan', 'school', '#3B82F6'),
  TypeInfo('other', 'Other Loan', 'wallet', '#64748B'),
];

TypeInfo loanType(String id) => loanTypes.firstWhere((l) => l.id == id, orElse: () => loanTypes.last);

const billCategories = [
  TypeInfo('rent', 'Rent', 'home', '#8B5CF6', 'rent'),
  TypeInfo('electricity', 'Electricity', 'flash', '#EAB308', 'bills'),
  TypeInfo('internet', 'Internet', 'wifi', '#0EA5E9', 'bills'),
  TypeInfo('phone', 'Mobile', 'call', '#22C55E', 'bills'),
  TypeInfo('insurance', 'Insurance', 'shield-checkmark', '#14B8A6', 'insurance'),
  TypeInfo('subscription', 'Subscription', 'play-circle', '#EC4899', 'subscriptions'),
  TypeInfo('other', 'Other', 'receipt', '#64748B', 'other'),
];

TypeInfo billCategory(String id) => billCategories.firstWhere((b) => b.id == id, orElse: () => billCategories.last);

const goalIcons = ['airplane', 'car-sport', 'home', 'laptop', 'school', 'heart', 'phone-portrait', 'umbrella', 'gift', 'trophy'];
const goalColors = ['#6366F1', '#22C55E', '#F97316', '#EC4899', '#0EA5E9', '#EAB308', '#14B8A6', '#8B5CF6'];

const frequencyLabels = {'weekly': 'Weekly', 'monthly': 'Monthly', 'quarterly': 'Quarterly', 'yearly': 'Yearly'};
