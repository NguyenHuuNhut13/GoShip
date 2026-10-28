export interface OrderItem {
  id: string;
  docId: string;
  customer: string;
  customerPhone: string;
  driver: string;
  driverPhone: string;
  vehicle: string;
  pickup: string;
  dropoff: string;
  fee: number;
  discount: number;
  paymentMethod: string;
  status: 'in_transit' | 'completed' | 'pending' | 'cancelled';
  time: string;
  date: string;
  podImg: string | null;
  isCloud?: boolean;
}

export interface DriverItem {
  id: string;
  docId: string;
  name: string;
  phone: string;
  email: string;
  vehicle: string;
  plate: string;
  rating: number;
  orders: number;
  status: 'active' | 'locked' | 'pending_approval';
  avatar: string;
  joinDate: string;
  revenue: number;
  cccd?: string;
  cccdFrontUrl?: string;
  cccdBackUrl?: string;
  isCloud?: boolean;
}

export interface CustomerItem {
  id: string;
  docId: string;
  name: string;
  phone: string;
  email: string;
  status: 'active' | 'locked';
  totalOrders: number;
  totalSpent: number;
  avatar: string;
  joinDate: string;
  address?: string;
  isCloud?: boolean;
}

export interface MapVehicleItem {
  id: string;
  driver: string;
  phone: string;
  vehicle: string;
  status: 'delivering' | 'idle';
  lat: number;
  lng: number;
  plate: string;
  activeOrder?: string;
  isCloud?: boolean;
}

export interface PricingRule {
  key: string;
  label: string;
  icon: string;
  base: number;
  perKm: number;
  peak: number;
  wait: number;
  min: number;
  isPeakActive: boolean;
}

export interface TransactionItem {
  id: string;
  driver: string;
  driverId: string;
  type: 'deposit' | 'withdraw' | 'commission' | 'refund';
  amount: number;
  balance: number;
  time: string;
  status: 'completed' | 'pending';
  note: string;
  isCloud?: boolean;
}

export interface PayoutRequestItem {
  id: string;
  docId: string;
  driverId: string;
  driverName: string;
  driverPhone: string;
  amount: number;
  bankName: string;
  accountNo: string;
  holderName: string;
  time: string;
  status: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  isCloud?: boolean;
}

export interface VoucherItem {
  id: string;
  docId: string;
  code: string;
  discountPercent?: number;
  discountAmount?: number;
  maxDiscount: number;
  minOrder: number;
  usageLimit: number;
  usedCount: number;
  expiryDate: string;
  isActive: boolean;
  description: string;
  isCloud?: boolean;
}

export interface IncidentItem {
  id: string;
  docId: string;
  orderId: string;
  driverName: string;
  customerName: string;
  type: 'sos' | 'accident' | 'breakdown' | 'dispute' | 'damage';
  status: 'pending' | 'resolved' | 'investigating';
  description: string;
  time: string;
  location?: string;
  severity: 'high' | 'medium' | 'low';
  isCloud?: boolean;
}

export interface TrendPoint {
  label: string;
  shortLabel: string;
  rev: number;
  orders: number;
}
