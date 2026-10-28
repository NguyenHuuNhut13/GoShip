import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  LayoutDashboard, Map, Package, Users, DollarSign, CreditCard,
  Search, Bell, ChevronDown, CheckCircle, XCircle, Clock, Truck,
  Eye, Lock, Unlock, Check, X, TrendingUp, AlertCircle, Filter,
  Download, RefreshCw, LogOut, Settings, Navigation, Phone, Star,
  ArrowUpRight, ArrowDownLeft, Percent, RotateCcw, Menu, ChevronRight,
  MapPin, Calendar, Layers, Shield, Sliders, FileText, Activity,
  EyeOff, KeyRound, UserCheck, Zap, BarChart2, Cloud, ExternalLink,
  Tag, AlertTriangle
} from 'lucide-react';
import {
  PieChart, Pie, Cell, Tooltip as RechartsTooltip, ResponsiveContainer
} from 'recharts';
import {
  fetchCollection,
  fetchDocument,
  patchDocumentFields,
  deleteDocument,
  createDocument,
} from '../services/firestoreCloud';
import {
  OrderItem, DriverItem, CustomerItem, MapVehicleItem,
  PricingRule, TransactionItem, PayoutRequestItem, VoucherItem,
  IncidentItem, TrendPoint
} from './types';
import { OrdersView } from './components/OrdersView';
import { CustomersView } from './components/CustomersView';
import { TransactionsView } from './components/TransactionsView';
import { VouchersView } from './components/VouchersView';
import { IncidentsView } from './components/IncidentsView';

declare global {
  interface Window {
    L: any;
  }
}

// ─── DEFAULT CONFIGS & SEED DATA ─────────────────────────────────────────────

const DEFAULT_PRICING: Record<string, PricingRule> = {
  motorbike: { key: 'motorbike', label: 'Xe Bán tải', icon: '🛻', base: 35000, perKm: 6000, peak: 1.2, wait: 2000, min: 35000, isPeakActive: false },
  van: { key: 'van', label: 'Xe van', icon: '🚐', base: 50000, perKm: 10000, peak: 1.2, wait: 3000, min: 50000, isPeakActive: false },
  truck: { key: 'truck', label: 'Xe tải', icon: '🚚', base: 120000, perKm: 15000, peak: 1.3, wait: 5000, min: 120000, isPeakActive: false },
  container: { key: 'container', label: 'Container', icon: '📦', base: 350000, perKm: 25000, peak: 1.3, wait: 10000, min: 350000, isPeakActive: false },
};

const DEFAULT_VOUCHERS: VoucherItem[] = [
  {
    id: 'vouch_1',
    docId: 'voucher_truck50',
    code: 'TRUCK50',
    discountPercent: 20,
    maxDiscount: 50000,
    minOrder: 100000,
    usageLimit: 100,
    usedCount: 16,
    expiryDate: '2026-12-31',
    isActive: true,
    description: 'Giảm 20% tối đa 50k cho khách hàng đặt xe tải',
    isCloud: true,
  },
  {
    id: 'vouch_2',
    docId: 'voucher_goship20',
    code: 'GOSHIP20',
    discountAmount: 20000,
    maxDiscount: 20000,
    minOrder: 50000,
    usageLimit: 200,
    usedCount: 42,
    expiryDate: '2026-12-31',
    isActive: true,
    description: 'Giảm ngay 20.000đ cước mở cửa cho khách hàng mới',
    isCloud: true,
  },
  {
    id: 'vouch_3',
    docId: 'voucher_freeship',
    code: 'FREESHIP',
    discountAmount: 30000,
    maxDiscount: 30000,
    minOrder: 80000,
    usageLimit: 50,
    usedCount: 5,
    expiryDate: '2026-11-30',
    isActive: true,
    description: 'Miễn phí cước chờ bốc xếp tối đa 30.000đ',
    isCloud: true,
  },
];

const DEFAULT_INCIDENTS: IncidentItem[] = [
  {
    id: 'INC-01',
    docId: 'inc_sample_1',
    orderId: '#GS-7721',
    driverName: 'Nguyễn Hữu Nhựt',
    customerName: 'Trần Thị Mai',
    type: 'breakdown',
    status: 'pending',
    description: 'Xe bị nổ lốp tại ngã tư Thủ Đức, cần điều phối xe bán tải khác tới chuyển hàng giúp khách.',
    time: '14:25 Hôm nay',
    location: 'Xa lộ Hà Nội, P. Linh Trung, TP. Thủ Đức',
    severity: 'medium',
    isCloud: true,
  },
];

const DEFAULT_PAYOUTS: PayoutRequestItem[] = [
  {
    id: 'PO-9921',
    docId: 'po_sample_1',
    driverId: 'drv_01',
    driverName: 'Nguyễn Hữu Nhựt',
    driverPhone: '0918234567',
    amount: 500000,
    bankName: 'Vietcombank',
    accountNo: '0071001234567',
    holderName: 'NGUYEN HUU NHUT',
    time: '10:15 Hôm nay',
    status: 'pending',
    isCloud: true,
  },
];

export interface TrendPoint {
  label: string;
  shortLabel: string;
  rev: number;
  orders: number;
}

function computeTrendData(orders: OrderItem[], range: 'week' | 'month' | 'year'): TrendPoint[] {
  const completedOrders = orders.filter(o => o.status === 'completed');
  const now = new Date();
  const curYear = now.getFullYear();
  const curMonth = now.getMonth() + 1; // 1-12

  if (range === 'week') {
    const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    const result: TrendPoint[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(now.getDate() - i);
      const dateStr = d.toLocaleDateString('vi-VN');
      const dayName = days[d.getDay()];
      const dayOrders = completedOrders.filter(o => o.date === dateStr);
      const rev = dayOrders.reduce((sum, o) => sum + o.fee, 0);
      result.push({
        label: `${dayName} (${d.getDate()}/${d.getMonth() + 1})`,
        shortLabel: dayName,
        rev,
        orders: dayOrders.length,
      });
    }
    return result;
  }

  if (range === 'month') {
    const weeks = [
      { shortLabel: 'Tuần 1', label: `Tuần 1 (01-07/Th${curMonth})`, minDay: 1, maxDay: 7 },
      { shortLabel: 'Tuần 2', label: `Tuần 2 (08-14/Th${curMonth})`, minDay: 8, maxDay: 14 },
      { shortLabel: 'Tuần 3', label: `Tuần 3 (15-21/Th${curMonth})`, minDay: 15, maxDay: 21 },
      { shortLabel: 'Tuần 4', label: `Tuần 4 (22-31/Th${curMonth})`, minDay: 22, maxDay: 31 },
    ];
    return weeks.map(w => {
      const matched = completedOrders.filter(o => {
        const parts = o.date.split('/');
        if (parts.length >= 2) {
          const day = parseInt(parts[0], 10);
          const month = parseInt(parts[1], 10);
          return month === curMonth && day >= w.minDay && day <= w.maxDay;
        }
        return false;
      });
      const rev = matched.reduce((sum, o) => sum + o.fee, 0);
      return {
        label: w.label,
        shortLabel: w.shortLabel,
        rev,
        orders: matched.length,
      };
    });
  }

  // range === 'year': 12 months
  const months = ['Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12'];
  return months.map((m, idx) => {
    const monthNum = idx + 1;
    const matched = completedOrders.filter(o => {
      const parts = o.date.split('/');
      if (parts.length >= 2) {
        const month = parseInt(parts[1], 10);
        return month === monthNum;
      }
      return false;
    });
    const rev = matched.reduce((sum, o) => sum + o.fee, 0);
    return {
      label: `Tháng ${monthNum}/${curYear}`,
      shortLabel: m,
      rev,
      orders: matched.length,
    };
  });
}

const fmtVND = (n: number) =>
  new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(n);

function normalizeOrderStatus(raw?: string): 'in_transit' | 'completed' | 'pending' | 'cancelled' {
  const s = (raw || '').toLowerCase().trim();
  if (s === 'completed' || s === 'delivered' || s.includes('hoàn thành') || s.includes('đã giao')) return 'completed';
  if (s === 'cancelled' || s === 'canceled' || s.includes('hủy')) return 'cancelled';
  if (s === 'accepted' || s === 'picked_up' || s === 'in_transit' || s === 'delivering' || s.includes('đang giao') || s.includes('đã nhận')) return 'in_transit';
  return 'pending';
}

// ─── BADGE COMPONENTS ─────────────────────────────────────────────────────────

const ORDER_STATUS_CONFIG: Record<string, { label: string; bg: string; text: string; dot: string }> = {
  in_transit: { label: 'Đang giao', bg: 'bg-blue-50', text: 'text-blue-700', dot: 'bg-blue-500' },
  completed: { label: 'Hoàn thành', bg: 'bg-emerald-50', text: 'text-emerald-700', dot: 'bg-emerald-500' },
  pending: { label: 'Chờ tài xế', bg: 'bg-amber-50', text: 'text-amber-700', dot: 'bg-amber-500' },
  cancelled: { label: 'Đã hủy', bg: 'bg-red-50', text: 'text-red-600', dot: 'bg-red-500' },
};

const DRIVER_STATUS_CONFIG: Record<string, { label: string; bg: string; text: string; dot: string }> = {
  active: { label: 'Hoạt động', bg: 'bg-emerald-50', text: 'text-emerald-700', dot: 'bg-emerald-500' },
  locked: { label: 'Bị khóa', bg: 'bg-red-50', text: 'text-red-600', dot: 'bg-red-500' },
  pending_approval: { label: 'Chờ duyệt', bg: 'bg-amber-50', text: 'text-amber-700', dot: 'bg-amber-500' },
};

const TXN_TYPE_CONFIG: Record<string, { label: string; bg: string; text: string; icon: React.ComponentType<any> }> = {
  deposit: { label: 'Nạp / Ký quỹ', bg: 'bg-emerald-50', text: 'text-emerald-700', icon: ArrowDownLeft },
  withdraw: { label: 'Rút tiền', bg: 'bg-orange-50', text: 'text-orange-700', icon: ArrowUpRight },
  commission: { label: 'Hoa hồng 15%', bg: 'bg-blue-50', text: 'text-blue-700', icon: Percent },
  refund: { label: 'Hoàn tiền', bg: 'bg-purple-50', text: 'text-purple-700', icon: RotateCcw },
};

function OrderBadge({ status }: { status: string }) {
  const cfg = ORDER_STATUS_CONFIG[status] ?? ORDER_STATUS_CONFIG.pending;
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${cfg.bg} ${cfg.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${cfg.dot}`} />
      {cfg.label}
    </span>
  );
}

function DriverBadge({ status }: { status: string }) {
  const cfg = DRIVER_STATUS_CONFIG[status] ?? DRIVER_STATUS_CONFIG.active;
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${cfg.bg} ${cfg.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${cfg.dot}`} />
      {cfg.label}
    </span>
  );
}

function Modal({ open, onClose, children, maxWidth = 'max-w-lg' }: { open: boolean; onClose: () => void; children: React.ReactNode; maxWidth?: string }) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ backgroundColor: 'rgba(15,23,42,0.55)', backdropFilter: 'blur(4px)' }}>
      <div className={`bg-white rounded-2xl shadow-2xl w-full ${maxWidth} overflow-hidden animate-in fade-in zoom-in-95 duration-150`}>
        {children}
      </div>
    </div>
  );
}

// ─── LOGIN SCREEN ────────────────────────────────────────────────────────────

function LoginScreen({ onLogin }: { onLogin: () => void }) {
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('admin123');
  const [showPass, setShowPass] = useState(false);
  const [remember, setRemember] = useState(true);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setError('Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.');
      return;
    }
    setError('');
    setLoading(true);
    setTimeout(() => {
      setLoading(false);
      if ((username === 'admin' || username === 'admin@goship.vn') && (password === 'admin123' || password === '123456')) {
        onLogin();
      } else {
        setError('Tài khoản hoặc mật khẩu không đúng. Gợi ý: admin / admin123');
      }
    }, 500);
  };

  return (
    <div className="min-h-screen w-full flex" style={{ background: '#F7F9FC' }}>
      <div
        className="hidden lg:flex lg:w-[54%] xl:w-[58%] flex-col justify-between p-12 relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #0F172A 0%, #1E3A5F 50%, #1d4ed8 100%)' }}
      >
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <svg className="absolute top-0 right-0 w-[600px] h-[600px] opacity-10" viewBox="0 0 600 600">
            <circle cx="400" cy="150" r="280" fill="none" stroke="#60a5fa" strokeWidth="1" />
            <circle cx="400" cy="150" r="200" fill="none" stroke="#60a5fa" strokeWidth="1" />
            <circle cx="400" cy="150" r="120" fill="none" stroke="#60a5fa" strokeWidth="1" />
          </svg>
        </div>

        <div className="relative z-10 flex items-center gap-3">
          <div className="w-11 h-11 rounded-2xl flex items-center justify-center shadow-lg" style={{ background: '#2563EB' }}>
            <Truck className="w-6 h-6 text-white" />
          </div>
          <div>
            <div className="text-white font-bold text-lg leading-none">GoShip Logistics</div>
            <div className="text-blue-300 text-xs mt-0.5">Cloud Firestore Command Center • goship-145a0</div>
          </div>
        </div>

        <div className="relative z-10 space-y-8">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium mb-4"
              style={{ background: 'rgba(37,99,235,0.35)', color: '#93c5fd', border: '1px solid rgba(96,165,250,0.3)' }}>
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              Kết nối trực tiếp 2 chiều với App Khách hàng & App Tài xế
            </div>
            <h1 className="text-white text-4xl font-bold leading-tight">
              Điều hành Đội xe &<br />
              <span style={{ color: '#60a5fa' }}>Đồng bộ Cloud</span> Thời gian thực
            </h1>
            <p className="text-slate-300 text-base mt-3 leading-relaxed max-w-md">
              Mọi thao tác duyệt/khóa tài xế, cập nhật bảng giá 4 dòng xe, giám sát GPS và đối soát ví ký quỹ đều có hiệu lực tức thì trên toàn hệ sinh thái GoShip.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-4 max-w-lg">
            {[
              { label: 'Dự án Firebase', value: 'goship-145a0', icon: Cloud, color: '#60a5fa' },
              { label: 'Bản đồ Điều phối', value: 'Leaflet GPS', icon: Navigation, color: '#34d399' },
              { label: 'Bảng giá Động', value: '4 Dòng xe', icon: Zap, color: '#fb923c' },
            ].map((s, i) => {
              const Icon = s.icon;
              return (
                <div key={i} className="rounded-2xl p-4" style={{ background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.1)' }}>
                  <Icon className="w-5 h-5 mb-2" style={{ color: s.color }} />
                  <div className="text-white font-bold text-lg leading-none">{s.value}</div>
                  <div className="text-slate-400 text-xs mt-1">{s.label}</div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="relative z-10 flex items-center justify-between text-xs text-slate-500">
          <span>© 2026 GoShip Logistics Cloud</span>
          <span>v3.0.0 — Synchronized Enterprise Release</span>
        </div>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center p-6 sm:p-12">
        <div className="w-full max-w-md">
          <div className="bg-white rounded-3xl p-8 shadow-xl border border-slate-100">
            <div className="mb-7">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-blue-50 text-blue-600 text-xs font-medium mb-3">
                <Shield className="w-3.5 h-3.5" /> Cổng Quản trị viên (Web & Mobile Sync)
              </div>
              <h2 className="text-slate-800 text-2xl font-bold">Đăng nhập hệ thống</h2>
              <p className="text-slate-400 text-sm mt-1">Sử dụng cùng tài khoản Admin với App Mobile GoShip</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1.5">Tên đăng nhập / Email</label>
                <div className="relative">
                  <UserCheck className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                  <input
                    type="text"
                    value={username}
                    onChange={e => setUsername(e.target.value)}
                    placeholder="admin hoặc admin@goship.vn"
                    className="w-full pl-10 pr-4 py-3 text-sm bg-slate-50 border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500/25 focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1.5">Mật khẩu</label>
                <div className="relative">
                  <KeyRound className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                  <input
                    type={showPass ? 'text' : 'password'}
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full pl-10 pr-11 py-3 text-sm bg-slate-50 border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500/25 focus:border-blue-500"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPass(v => !v)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    {showPass ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {error && (
                <div className="flex items-center gap-2 px-3.5 py-2.5 bg-red-50 border border-red-200 rounded-xl text-xs text-red-600">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  {error}
                </div>
              )}

              <div className="flex items-center justify-between pt-1">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={remember}
                    onChange={e => setRemember(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-300 text-blue-600"
                  />
                  <span className="text-xs text-slate-600">Ghi nhớ đăng nhập</span>
                </label>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 rounded-xl text-white text-sm font-semibold flex items-center justify-center gap-2 shadow-lg transition-all mt-2 disabled:opacity-70"
                style={{ background: 'linear-gradient(135deg, #2563EB, #1d4ed8)', boxShadow: '0 4px 14px rgba(37,99,235,0.35)' }}
              >
                {loading ? 'Đang kết nối Cloud Firestore...' : 'Đăng nhập Quản trị viên'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── 1. DASHBOARD VIEW ────────────────────────────────────────────────────────

function DashboardView({
  orders,
  vehicles,
  incidents = [],
  onNavigate,
}: {
  orders: OrderItem[];
  vehicles: MapVehicleItem[];
  incidents?: IncidentItem[];
  onNavigate: (tab: string) => void;
}) {
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'year'>('week');
  const [hoveredPoint, setHoveredPoint] = useState<TrendPoint | null>(null);

  const pendingIncidents = incidents.filter(i => i.status !== 'resolved');

  const completedCount = orders.filter(o => o.status === 'completed').length;
  const inTransitCount = orders.filter(o => o.status === 'in_transit').length;
  const pendingCount = orders.filter(o => o.status === 'pending').length;
  const cancelledCount = orders.filter(o => o.status === 'cancelled').length;
  const totalCount = orders.length || 1;

  const totalRevenue = orders
    .filter(o => o.status === 'completed')
    .reduce((sum, o) => sum + o.fee, 0);
  const platformCommission = Math.round(totalRevenue * 0.15);
  const completionRate = ((completedCount / totalCount) * 100).toFixed(1);

  const orderDist = [
    { name: 'Hoàn thành', value: Math.round((completedCount / totalCount) * 100), count: completedCount, color: '#10B981' },
    { name: 'Đang giao', value: Math.round((inTransitCount / totalCount) * 100), count: inTransitCount, color: '#2563EB' },
    { name: 'Chờ tài xế', value: Math.round((pendingCount / totalCount) * 100), count: pendingCount, color: '#F59E0B' },
    { name: 'Đã hủy', value: Math.round((cancelledCount / totalCount) * 100), count: cancelledCount, color: '#EF4444' },
  ];

  const kpis = [
    {
      title: 'Tổng đơn hàng hệ thống',
      value: `${orders.length} đơn`,
      sub: `${inTransitCount} đang giao • ${pendingCount} chờ nhận`,
      up: true,
      icon: Package,
      iconBg: 'bg-blue-50',
      iconColor: 'text-blue-600',
      accent: '#2563EB',
    },
    {
      title: 'Doanh thu đơn hoàn tất',
      value: fmtVND(totalRevenue),
      sub: `Hoa hồng sàn 15%: ${fmtVND(platformCommission)}`,
      up: true,
      icon: DollarSign,
      iconBg: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      accent: '#10B981',
    },
    {
      title: 'Đội xe đang Trực tuyến',
      value: `${vehicles.length} xe`,
      sub: `${vehicles.filter(v => v.status === 'delivering').length} đang chở hàng • ${vehicles.filter(v => v.status === 'idle').length} đang rảnh`,
      up: true,
      icon: Truck,
      iconBg: 'bg-orange-50',
      iconColor: 'text-orange-500',
      accent: '#FF6B00',
    },
    {
      title: 'Tỷ lệ giao hoàn tất',
      value: `${completionRate}%`,
      sub: `${completedCount} hoàn thành / ${cancelledCount} đã hủy`,
      up: true,
      icon: CheckCircle,
      iconBg: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      accent: '#10B981',
    },
  ];

  const trendData = computeTrendData(orders, timeRange);
  const maxRev = Math.max(...trendData.map(d => d.rev), 50000);
  const minRev = Math.min(...trendData.map(d => d.rev), 0);
  const svgW = 540, svgH = 190, padL = 20, padR = 20, padT = 25, padB = 28;
  const chartW = svgW - padL - padR;
  const chartH = svgH - padT - padB;
  const revPts = trendData.map((d, i) => {
    const norm = (d.rev - minRev * 0.85) / (maxRev * 1.1 - minRev * 0.85 || 1);
    return {
      x: padL + (i / Math.max(trendData.length - 1, 1)) * chartW,
      y: padT + (1 - norm) * chartH,
      ...d,
    };
  });
  const linePath = revPts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
  const areaPath = `${linePath} L${revPts[revPts.length - 1].x.toFixed(1)},${(padT + chartH).toFixed(1)} L${revPts[0].x.toFixed(1)},${(padT + chartH).toFixed(1)} Z`;

  return (
    <div className="space-y-6">
      {/* Quick Incident / SOS Alert Banner if any unresolved */}
      {pendingIncidents.length > 0 && (
        <div className="bg-gradient-to-r from-red-600 to-amber-600 text-white rounded-2xl p-4 shadow-md flex flex-wrap items-center justify-between gap-3 animate-in fade-in">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
              <AlertTriangle className="w-5 h-5 text-white animate-bounce" />
            </div>
            <div>
              <div className="font-bold text-sm leading-tight">
                CẢNH BÁO AN TOÀN ĐỘI XE: Có {pendingIncidents.length} sự cố chuyến đi đang chờ xử lý!
              </div>
              <div className="text-red-100 text-xs mt-0.5">
                Bao gồm tín hiệu SOS khẩn cấp, sự cố xe và khiếu nại cước từ tài xế/khách hàng.
              </div>
            </div>
          </div>
          <button
            onClick={() => onNavigate('incidents')}
            className="px-4 py-2 rounded-xl bg-white text-red-700 text-xs font-bold hover:bg-red-50 transition-colors shadow-xs"
          >
            Mở Trung tâm Sự cố & SOS →
          </button>
        </div>
      )}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5">
        {kpis.map((k, idx) => {
          const Icon = k.icon;
          return (
            <div key={idx} className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-xs text-slate-500 font-medium">{k.title}</p>
                  <p className="text-2xl font-bold text-slate-800 mt-1.5">{k.value}</p>
                </div>
                <div className={`p-3 rounded-xl ${k.iconBg}`}>
                  <Icon className={`w-5 h-5 ${k.iconColor}`} />
                </div>
              </div>
              <div className="mt-3 flex items-center gap-1.5">
                <TrendingUp className="w-3.5 h-3.5 text-emerald-500" />
                <span className="text-xs font-medium text-emerald-600">{k.sub}</span>
              </div>
              <div className="mt-3 h-1 rounded-full bg-slate-100 overflow-hidden">
                <div className="h-full rounded-full" style={{ width: '78%', backgroundColor: k.accent }} />
              </div>
            </div>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-slate-100 shadow-sm relative">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-slate-800 font-semibold text-base">Biểu đồ tăng trưởng doanh thu</h3>
                <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-blue-50 text-blue-600">
                  {timeRange === 'week' ? 'MỐC TUẦN' : timeRange === 'month' ? 'MỐC THÁNG' : 'MỐC NĂM'}
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                {timeRange === 'week' && 'Theo dõi 7 ngày gần nhất từ Cloud Firestore'}
                {timeRange === 'month' && 'Theo dõi theo 4 tuần của tháng hiện tại'}
                {timeRange === 'year' && 'Theo dõi cả 12 tháng trong năm hiện tại'}
              </p>
            </div>

            <div className="flex items-center gap-2">
              <div className="flex items-center bg-slate-100 p-1 rounded-xl">
                {[
                  { key: 'week', label: 'Tuần' },
                  { key: 'month', label: 'Tháng' },
                  { key: 'year', label: 'Năm' },
                ].map(t => (
                  <button
                    key={t.key}
                    onClick={() => {
                      setTimeRange(t.key as any);
                      setHoveredPoint(null);
                    }}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                      timeRange === t.key
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>

              <button
                onClick={() => onNavigate('orders')}
                className="text-xs bg-blue-50 text-blue-600 px-3 py-2 rounded-xl font-medium hover:bg-blue-100 transition-colors"
              >
                Quản lý đơn hàng →
              </button>
            </div>
          </div>

          {hoveredPoint && (
            <div className="absolute top-16 left-6 z-10 px-3 py-1.5 rounded-xl bg-slate-900/90 text-white text-xs shadow-lg border border-slate-700 flex items-center gap-2 animate-in fade-in">
              <span className="font-semibold text-blue-300">{hoveredPoint.label}:</span>
              <span className="font-bold text-emerald-400">{fmtVND(hoveredPoint.rev)}</span>
              <span className="text-slate-300 font-normal">({hoveredPoint.orders} đơn hoàn tất)</span>
            </div>
          )}

          <svg viewBox={`0 0 ${svgW} ${svgH}`} className="w-full" style={{ height: 200 }}>
            <defs>
              <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#2563EB" stopOpacity={0.2} />
                <stop offset="100%" stopColor="#2563EB" stopOpacity={0} />
              </linearGradient>
            </defs>
            <path d={areaPath} fill="url(#revGrad)" />
            <path d={linePath} fill="none" stroke="#2563EB" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
            {revPts.map((p, i) => (
              <g
                key={i}
                className="cursor-pointer"
                onMouseEnter={() => setHoveredPoint(p)}
                onMouseLeave={() => setHoveredPoint(null)}
              >
                <circle
                  cx={p.x}
                  cy={p.y}
                  r={hoveredPoint?.shortLabel === p.shortLabel ? 6 : 4.5}
                  fill="#2563EB"
                  stroke="#fff"
                  strokeWidth={2}
                  className="transition-all"
                />
                <text
                  x={p.x}
                  y={svgH - 6}
                  textAnchor="middle"
                  fontSize={timeRange === 'year' ? 9.5 : 11}
                  fill={hoveredPoint?.shortLabel === p.shortLabel ? '#2563EB' : '#94a3b8'}
                  fontWeight={hoveredPoint?.shortLabel === p.shortLabel ? 'bold' : 'normal'}
                >
                  {p.shortLabel}
                </text>
              </g>
            ))}
          </svg>
        </div>

        <div className="bg-white rounded-2xl p-6 border border-slate-100 shadow-sm flex flex-col">
          <div className="mb-3">
            <h3 className="text-slate-800 font-semibold text-base">Phân bổ đơn hàng</h3>
            <p className="text-xs text-slate-400 mt-0.5">Tổng cộng {orders.length} đơn trên hệ thống</p>
          </div>
          <div className="flex-1 flex flex-col items-center justify-center">
            <ResponsiveContainer width="100%" height={165}>
              <PieChart>
                <Pie data={orderDist} cx="50%" cy="50%" innerRadius={46} outerRadius={72} paddingAngle={3} dataKey="value">
                  {orderDist.map((entry, index) => (
                    <Cell key={index} fill={entry.color} />
                  ))}
                </Pie>
                <RechartsTooltip formatter={(v: any) => [`${v}%`, '']} />
              </PieChart>
            </ResponsiveContainer>
            <div className="w-full grid grid-cols-2 gap-2 mt-1">
              {orderDist.map((d, i) => (
                <div key={i} className="flex items-center gap-2 text-xs">
                  <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                  <span className="text-slate-600 truncate">{d.name}</span>
                  <span className="ml-auto font-semibold text-slate-800">{d.count} ({d.value}%)</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── 2. FLEET MAP VIEW (LEAFLET REAL OPENSTREETMAP + LIVE GPS) ───────────────

function FleetMapView({ vehicles }: { vehicles: MapVehicleItem[] }) {
  const [filterStatus, setFilterStatus] = useState<'all' | 'delivering' | 'idle'>('all');
  const [selectedVehicle, setSelectedVehicle] = useState<MapVehicleItem | null>(null);
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const leafletMapRef = useRef<any>(null);
  const markersLayerRef = useRef<any>(null);

  const filtered = filterStatus === 'all' ? vehicles : vehicles.filter(v => v.status === filterStatus);
  const deliveringCount = vehicles.filter(v => v.status === 'delivering').length;
  const idleCount = vehicles.filter(v => v.status === 'idle').length;

  useEffect(() => {
    if (!mapContainerRef.current || !window.L) return;
    if (!leafletMapRef.current) {
      const L = window.L;
      const map = L.map(mapContainerRef.current, {
        center: [10.7769, 106.7009],
        zoom: 13,
      });
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors • GoShip Live Dispatch',
      }).addTo(map);
      markersLayerRef.current = L.layerGroup().addTo(map);
      leafletMapRef.current = map;
    }
  }, []);

  useEffect(() => {
    if (!leafletMapRef.current || !markersLayerRef.current || !window.L) return;
    const L = window.L;
    const layer = markersLayerRef.current;
    layer.clearLayers();

    filtered.forEach((v) => {
      const color = v.status === 'delivering' ? '#FF6B00' : '#10B981';
      const iconHtml = `
        <div style="display:flex;flex-direction:column;align-items:center;transform:translateY(-12px);">
          <div style="background:#0F172A;color:#fff;font-size:10px;font-weight:700;padding:2px 6px;border-radius:6px;border:1.5px solid ${color};white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,0.3);">
            ${v.plate} ${v.isCloud ? '• LIVE' : ''}
          </div>
          <div style="width:28px;height:28px;border-radius:50%;background:${color};border:2.5px solid #fff;display:flex;align-items:center;justify-content:center;color:#fff;font-size:13px;box-shadow:0 3px 10px rgba(0,0,0,0.35);margin-top:2px;">
            🚚
          </div>
        </div>
      `;
      const customIcon = L.divIcon({
        html: iconHtml,
        className: 'goship-driver-marker',
        iconSize: [90, 48],
        iconAnchor: [45, 36],
      });

      const marker = L.marker([v.lat, v.lng], { icon: customIcon });
      marker.on('click', () => setSelectedVehicle(v));
      marker.addTo(layer);
    });
  }, [filtered]);

  return (
    <div className="space-y-4">
      <div className="rounded-2xl overflow-hidden shadow-lg" style={{ background: '#0F172A' }}>
        <div className="px-6 py-4 flex flex-wrap items-center justify-between gap-4 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-blue-600/20 border border-blue-500/30">
              <Navigation className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-white font-semibold text-base">Bản đồ Điều hành Đội xe (OpenStreetMap Live)</h3>
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  CLOUD GPS
                </span>
              </div>
              <p className="text-slate-400 text-xs mt-0.5">Đồng bộ tọa độ trực tiếp từ collection `driver_tracking` trên Firestore</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 px-3.5 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
              <div>
                <div className="text-xs text-slate-400">Đang rảnh</div>
                <div className="text-base font-bold text-emerald-400">{idleCount} xe</div>
              </div>
            </div>
            <div className="flex items-center gap-2 px-3.5 py-2 rounded-xl bg-orange-500/10 border border-orange-500/20">
              <span className="w-2.5 h-2.5 rounded-full bg-orange-400 animate-pulse" />
              <div>
                <div className="text-xs text-slate-400">Đang giao</div>
                <div className="text-base font-bold text-orange-400">{deliveringCount} xe</div>
              </div>
            </div>
            <div className="flex items-center gap-2 px-3.5 py-2 rounded-xl bg-blue-500/10 border border-blue-500/20">
              <Truck className="w-4 h-4 text-blue-400" />
              <div>
                <div className="text-xs text-slate-400">Tổng Online</div>
                <div className="text-base font-bold text-blue-400">{vehicles.length} xe</div>
              </div>
            </div>
          </div>
        </div>

        <div className="px-6 py-3 flex flex-wrap items-center justify-between gap-3 bg-slate-900/60 border-b border-slate-800">
          <div className="flex items-center gap-2">
            {[
              { key: 'all', label: `Tất cả xe (${vehicles.length})` },
              { key: 'delivering', label: `Đang giao (${deliveringCount})` },
              { key: 'idle', label: `Đang rảnh (${idleCount})` },
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setFilterStatus(tab.key as any)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-medium transition-all ${
                  filterStatus === tab.key
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
          <span className="text-xs text-slate-400">Nhấn vào xe trên bản đồ để xem chi tiết tài xế & đơn hàng</span>
        </div>

        <div className="relative" style={{ height: 500 }}>
          <div ref={mapContainerRef} className="w-full h-full" />

          {filtered.length === 0 && (
            <div
              className="absolute top-4 left-4 z-[500] rounded-xl px-4 py-2.5 shadow-lg border border-slate-700 flex items-center gap-2.5 text-xs text-slate-300"
              style={{ background: 'rgba(15,23,42,0.92)', backdropFilter: 'blur(8px)' }}
            >
              <Navigation className="w-4 h-4 text-emerald-400" />
              <span>Chưa có tài xế nào bật GPS trực tuyến trên Cloud Firestore. Bản đồ đang hiển thị vị trí mặc định TP.HCM.</span>
            </div>
          )}

          {selectedVehicle && (
            <div
              className="absolute top-4 right-4 z-[500] rounded-2xl p-4 w-72 shadow-2xl border border-slate-700"
              style={{ background: 'rgba(15,23,42,0.95)', backdropFilter: 'blur(8px)' }}
            >
              <div className="flex items-start justify-between mb-2">
                <div>
                  <span className="text-white font-bold text-sm">{selectedVehicle.driver}</span>
                  <div className="text-xs text-slate-400">{selectedVehicle.vehicle} • {selectedVehicle.plate}</div>
                </div>
                <button onClick={() => setSelectedVehicle(null)} className="text-slate-400 hover:text-white">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="text-xs text-slate-300 space-y-1 mt-2">
                <div>📞 SĐT: <span className="font-semibold text-white">{selectedVehicle.phone || 'Đang cập nhật'}</span></div>
                <div>📍 Tọa độ: <span className="font-mono text-slate-400">{selectedVehicle.lat.toFixed(4)}, {selectedVehicle.lng.toFixed(4)}</span></div>
                {selectedVehicle.activeOrder && (
                  <div className="text-orange-400 font-semibold">📦 Đơn đang chạy: {selectedVehicle.activeOrder}</div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── 3. ORDERS VIEW (IMPORTED FROM ./components/OrdersView) ─────────────────
// Includes real-time Firestore sync, e-POD preview, Manual Dispatching, CSV export and Pagination


// ─── 4. DRIVERS VIEW (WITH CLOUD APPROVAL, LOCKING & KYC VIEWER) ─────────────

function DriversView({
  drivers,
  onUpdateDriverStatus,
}: {
  drivers: DriverItem[];
  onUpdateDriverStatus: (driver: DriverItem, newStatus: 'active' | 'locked') => Promise<void>;
}) {
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [selectedDriverKyc, setSelectedDriverKyc] = useState<DriverItem | null>(null);

  const pendingCount = drivers.filter(d => d.status === 'pending_approval').length;

  const filtered = drivers.filter(d => {
    const matchStatus = statusFilter === 'all' || d.status === statusFilter;
    const q = search.toLowerCase();
    const matchSearch =
      d.name.toLowerCase().includes(q) ||
      d.phone.includes(search) ||
      d.plate.toLowerCase().includes(q);
    return matchStatus && matchSearch;
  });

  return (
    <div className="space-y-5">
      {pendingCount > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-2xl px-5 py-3.5 flex items-center justify-between">
          <div className="flex items-center gap-2.5 text-amber-800 text-sm font-medium">
            <AlertCircle className="w-5 h-5 text-amber-600" />
            Có <strong>{pendingCount} hồ sơ đối tác tài xế</strong> mới đăng ký từ App Mobile đang chờ phê duyệt!
          </div>
          <button
            onClick={() => setStatusFilter('pending_approval')}
            className="text-xs font-bold text-amber-900 bg-amber-200/70 px-3 py-1.5 rounded-lg hover:bg-amber-200"
          >
            Lọc hồ sơ chờ duyệt →
          </button>
        </div>
      )}

      <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-1.5">
          {[
            { key: 'all', label: `Tất cả (${drivers.length})` },
            { key: 'active', label: `Hoạt động (${drivers.filter(d => d.status === 'active').length})` },
            { key: 'pending_approval', label: `Chờ duyệt (${pendingCount})` },
            { key: 'locked', label: `Bị khóa (${drivers.filter(d => d.status === 'locked').length})` },
          ].map(t => (
            <button
              key={t.key}
              onClick={() => setStatusFilter(t.key)}
              className={`px-3.5 py-2 rounded-xl text-xs font-medium transition-all ${
                statusFilter === t.key
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="relative flex-1 min-w-52 max-w-xs">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Tìm tài xế, SĐT, biển số..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
          />
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/70">
                <th className="text-left px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Đối tác Tài xế</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Liên hệ</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Phương tiện</th>
                <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Đánh giá</th>
                <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Trạng thái</th>
                <th className="text-center px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Hành động (Cloud Sync)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-12 text-center text-slate-400">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <Users className="w-8 h-8 text-slate-300" />
                      <p className="text-sm font-medium text-slate-600">Chưa có đối tác tài xế nào trong mục này</p>
                      <p className="text-xs text-slate-400">Tài xế đăng ký từ App Driver hoặc bật GPS sẽ được đồng bộ trực tiếp lên Cloud Firestore.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(driver => (
                  <tr key={driver.docId} className="hover:bg-slate-50/60 transition-colors">
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-3">
                      <img src={driver.avatar} alt={driver.name} className="w-10 h-10 rounded-full object-cover ring-2 ring-slate-100" />
                      <div>
                        <div className="font-semibold text-slate-800 flex items-center gap-1.5">
                          {driver.name}
                          {driver.isCloud && (
                            <span className="px-1.5 py-0.5 text-[10px] font-bold bg-blue-50 text-blue-600 rounded">CLOUD</span>
                          )}
                        </div>
                        <div className="text-xs text-slate-400">CCCD: {driver.cccd || 'Đã xác thực'}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-4">
                    <div className="text-slate-700 font-medium">{driver.phone}</div>
                    <div className="text-xs text-slate-400">{driver.email}</div>
                  </td>
                  <td className="px-4 py-4">
                    <div className="text-slate-700 font-medium">{driver.vehicle}</div>
                    <div className="text-xs text-slate-400 font-mono">{driver.plate}</div>
                  </td>
                  <td className="px-4 py-4 text-center">
                    <span className="inline-flex items-center gap-1 font-semibold text-amber-600">
                      <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                      {driver.rating.toFixed(1)}
                    </span>
                  </td>
                  <td className="px-4 py-4 text-center">
                    <DriverBadge status={driver.status} />
                  </td>
                  <td className="px-5 py-4 text-center">
                    <div className="inline-flex items-center gap-1.5">
                      <button
                        onClick={() => setSelectedDriverKyc(driver)}
                        className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                      >
                        <Eye className="w-3.5 h-3.5" /> Hồ sơ
                      </button>
                      {driver.status === 'pending_approval' ? (
                        <>
                          <button
                            onClick={() => onUpdateDriverStatus(driver, 'active')}
                            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
                          >
                            <Check className="w-3.5 h-3.5" /> Duyệt
                          </button>
                          <button
                            onClick={() => onUpdateDriverStatus(driver, 'locked')}
                            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                          >
                            <X className="w-3.5 h-3.5" /> Từ chối
                          </button>
                        </>
                      ) : driver.status === 'active' ? (
                        <button
                          onClick={() => onUpdateDriverStatus(driver, 'locked')}
                          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                        >
                          <Lock className="w-3.5 h-3.5" /> Khóa TK
                        </button>
                      ) : (
                        <button
                          onClick={() => onUpdateDriverStatus(driver, 'active')}
                          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-blue-50 text-blue-600 hover:bg-blue-100 transition-colors"
                        >
                          <Unlock className="w-3.5 h-3.5" /> Mở khóa
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
            </tbody>
          </table>
        </div>
      </div>

      <Modal open={!!selectedDriverKyc} onClose={() => setSelectedDriverKyc(null)}>
        {selectedDriverKyc && (
          <div>
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <img src={selectedDriverKyc.avatar} alt="" className="w-11 h-11 rounded-full object-cover" />
                <div>
                  <h4 className="font-bold text-slate-800">{selectedDriverKyc.name}</h4>
                  <p className="text-xs text-slate-400">{selectedDriverKyc.phone} • {selectedDriverKyc.vehicle} ({selectedDriverKyc.plate})</p>
                </div>
              </div>
              <button onClick={() => setSelectedDriverKyc(null)} className="p-2 rounded-xl hover:bg-slate-100 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-3 text-xs">
                <div className="bg-slate-50 p-3 rounded-xl">
                  <span className="text-slate-400">Số CCCD định danh:</span>
                  <div className="font-bold text-slate-800 mt-0.5">{selectedDriverKyc.cccd || '070204000284'}</div>
                </div>
                <div className="bg-slate-50 p-3 rounded-xl">
                  <span className="text-slate-400">Trạng thái tài khoản:</span>
                  <div className="mt-1"><DriverBadge status={selectedDriverKyc.status} /></div>
                </div>
              </div>
              {selectedDriverKyc.cccdFrontUrl && (
                <div>
                  <div className="text-xs font-semibold text-slate-500 mb-1.5">Ảnh CCCD Mặt trước:</div>
                  <img src={selectedDriverKyc.cccdFrontUrl} alt="CCCD Front" className="w-full h-36 object-cover rounded-xl border" />
                </div>
              )}
              {selectedDriverKyc.cccdBackUrl && (
                <div>
                  <div className="text-xs font-semibold text-slate-500 mb-1.5">Ảnh CCCD Mặt sau:</div>
                  <img src={selectedDriverKyc.cccdBackUrl} alt="CCCD Back" className="w-full h-36 object-cover rounded-xl border" />
                </div>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}

// ─── 5. PRICING VIEW (4 GOSHIP VEHICLES SYNCED WITH CLOUD FIRESTORE) ─────────

function PricingView({
  pricing,
  onSavePricing,
}: {
  pricing: Record<string, PricingRule>;
  onSavePricing: (newPricing: Record<string, PricingRule>) => Promise<boolean>;
}) {
  const [localPricing, setLocalPricing] = useState<Record<string, PricingRule>>(pricing);
  const [activeVehicle, setActiveVehicle] = useState<string>('motorbike');
  const [simKm, setSimKm] = useState<number>(5);
  const [saving, setSaving] = useState(false);
  const [savedToast, setSavedToast] = useState(false);

  useEffect(() => {
    setLocalPricing(pricing);
  }, [pricing]);

  const current = localPricing[activeVehicle] || DEFAULT_PRICING.motorbike;

  const handleChange = (field: keyof PricingRule, val: any) => {
    setLocalPricing(prev => ({
      ...prev,
      [activeVehicle]: {
        ...prev[activeVehicle],
        [field]: val,
      },
    }));
  };

  const handleSave = async () => {
    setSaving(true);
    await onSavePricing(localPricing);
    setSaving(false);
    setSavedToast(true);
    setTimeout(() => setSavedToast(false), 3000);
  };

  const handleReset = async () => {
    setLocalPricing(DEFAULT_PRICING);
    await onSavePricing(DEFAULT_PRICING);
  };

  // Simulator calculation
  const simDistance = Math.max(1, simKm);
  const simBase = current.base;
  const simNextKm = Math.max(0, simDistance - 2) * current.perKm;
  const simSubtotal = simBase + simNextKm;
  const simPeakMultiplier = current.isPeakActive ? current.peak : 1.0;
  const simRawTotal = Math.round(simSubtotal * simPeakMultiplier);
  const simTotal = Math.max(simRawTotal, current.min);
  const simCommission = Math.round(simTotal * 0.15);
  const simDriverNet = simTotal - simCommission;

  const fields = [
    { key: 'base', label: 'Cước mở cửa (2km đầu)', unit: 'VNĐ', step: 5000, desc: 'Phí khởi điểm cho mỗi chuyến hàng' },
    { key: 'perKm', label: 'Giá cước mỗi km tiếp theo', unit: 'VNĐ/km', step: 1000, desc: 'Tính từ km thứ 3 trở đi' },
    { key: 'min', label: 'Cước tối thiểu mỗi chuyến', unit: 'VNĐ', step: 5000, desc: 'Mức phí thấp nhất áp dụng cho 1 đơn' },
    { key: 'peak', label: 'Hệ số giờ cao điểm', unit: 'x lần', step: 0.1, desc: 'Nhân hệ số khi bật chế độ Giờ cao điểm' },
    { key: 'wait', label: 'Phí chờ bốc xếp', unit: 'VNĐ/phút', step: 500, desc: 'Miễn phí 10 phút đầu tiên' },
  ];

  return (
    <div className="w-full max-w-7xl mx-auto space-y-6">
      {/* Top Header Selector Card */}
      <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-slate-800 font-bold text-lg flex items-center gap-2">
            <DollarSign className="w-5 h-5 text-blue-600" />
            Cấu hình Bảng giá Động (Cloud Realtime Sync)
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Lưu trực tiếp vào Firestore <code className="bg-slate-100 px-1 py-0.5 rounded text-blue-600 font-mono">pricing_config/default</code> • Áp dụng tức thì cho App Khách hàng & Tài xế
          </p>
        </div>

        {/* Tab Pills */}
        <div className="flex flex-wrap items-center gap-2 bg-slate-50 p-1.5 rounded-2xl border border-slate-200">
          {Object.entries(localPricing).map(([key, val]) => (
            <button
              key={key}
              onClick={() => setActiveVehicle(key)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
                activeVehicle === key
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50'
              }`}
            >
              <span className="text-sm">{val.icon}</span>
              {val.label}
              {val.isPeakActive && (
                <span className="w-2 h-2 rounded-full bg-orange-400 animate-pulse" title="Đang bật giờ cao điểm" />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Main Balanced 2-Column Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Configuration Settings (Col 7) */}
        <div className="lg:col-span-7 space-y-5">
          <div className="bg-white rounded-2xl p-6 border border-slate-100 shadow-sm space-y-5">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-2xl bg-blue-50 text-2xl flex items-center justify-center border border-blue-100">
                  {current.icon}
                </div>
                <div>
                  <h3 className="text-slate-800 font-bold text-base flex items-center gap-2">
                    Thông số cước — {current.label}
                  </h3>
                  <span className="text-xs text-slate-400">
                    Phân khúc: {current.key} • Tự động tính cước tự động trên ứng dụng GoShip
                  </span>
                </div>
              </div>

              {savedToast && (
                <div className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-700 rounded-xl text-xs font-semibold animate-in fade-in">
                  <CheckCircle className="w-4 h-4 text-emerald-600" /> Đã lưu Cloud!
                </div>
              )}
            </div>

            {/* Input Form Fields */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {fields.map(f => (
                <div key={f.key} className="space-y-1.5">
                  <label className="block text-xs font-semibold text-slate-700">{f.label}</label>
                  <div className="relative">
                    <input
                      type="number"
                      step={f.step}
                      value={(current as any)[f.key]}
                      onChange={e => handleChange(f.key as keyof PricingRule, parseFloat(e.target.value) || 0)}
                      className="w-full pr-18 pl-4 py-2.5 text-sm font-semibold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
                    />
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-400 font-medium">{f.unit}</span>
                  </div>
                  <p className="text-[11px] text-slate-400">{f.desc}</p>
                </div>
              ))}
            </div>

            {/* Peak Hours Activation Toggle Card */}
            <div className={`p-4 rounded-2xl border transition-all flex items-center justify-between gap-4 ${
              current.isPeakActive ? 'bg-orange-50/80 border-orange-200' : 'bg-slate-50 border-slate-200'
            }`}>
              <div className="space-y-0.5">
                <div className="text-sm font-bold text-slate-800 flex items-center gap-1.5">
                  <Zap className={`w-4 h-4 ${current.isPeakActive ? 'text-orange-500 fill-orange-500' : 'text-slate-400'}`} />
                  Kích hoạt Phụ phí Giờ cao điểm
                </div>
                <div className="text-xs text-slate-500">
                  {current.isPeakActive
                    ? `Đang áp dụng hệ số nhân x${current.peak} cho dòng xe ${current.label}`
                    : 'Đang áp dụng mức giá cơ bản tiêu chuẩn (hệ số x1.0)'}
                </div>
              </div>
              <label className="relative inline-flex items-center cursor-pointer shrink-0">
                <input
                  type="checkbox"
                  checked={current.isPeakActive}
                  onChange={e => handleChange('isPeakActive', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-orange-500"></div>
              </label>
            </div>

            {/* Actions */}
            <div className="flex items-center gap-3 pt-3 border-t border-slate-100">
              <button
                onClick={handleSave}
                disabled={saving}
                className="px-6 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-semibold transition-colors shadow-sm flex items-center gap-2 disabled:opacity-60 cursor-pointer"
              >
                <Check className="w-4 h-4" /> {saving ? 'Đang lưu Cloud Firestore...' : 'Lưu bảng giá lên Cloud'}
              </button>
              <button
                onClick={handleReset}
                className="px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-600 rounded-xl text-sm font-medium transition-colors flex items-center gap-2 cursor-pointer"
              >
                <RefreshCw className="w-4 h-4" /> Khôi phục mặc định
              </button>
            </div>
          </div>
        </div>

        {/* Right Column: Interactive Simulator & Fleet Pricing Matrix (Col 5) */}
        <div className="lg:col-span-5 space-y-5">
          {/* Fare Simulator Card */}
          <div className="bg-white rounded-2xl p-6 border border-slate-100 shadow-sm space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <div className="p-2 rounded-xl bg-emerald-50 text-emerald-600">
                  <Activity className="w-4 h-4" />
                </div>
                <h4 className="text-sm font-bold text-slate-800">Mô phỏng Tính cước Trực quan</h4>
              </div>
              <span className="text-xs font-semibold px-2.5 py-1 bg-blue-50 text-blue-700 rounded-lg">
                {current.label}
              </span>
            </div>

            {/* Slider */}
            <div>
              <div className="flex items-center justify-between text-xs mb-2">
                <span className="text-slate-500">Khoảng cách cuốc xe giả lập:</span>
                <span className="font-bold text-slate-800 text-sm bg-slate-100 px-2.5 py-0.5 rounded-md">
                  {simKm} km
                </span>
              </div>
              <input
                type="range"
                min="1"
                max="50"
                step="1"
                value={simKm}
                onChange={e => setSimKm(parseInt(e.target.value, 10) || 1)}
                className="w-full accent-blue-600 cursor-pointer"
              />
              <div className="flex items-center justify-between gap-1.5 mt-2">
                {[3, 5, 10, 20, 35].map(k => (
                  <button
                    key={k}
                    onClick={() => setSimKm(k)}
                    className={`px-2 py-1 rounded-lg text-[11px] font-medium transition-colors ${
                      simKm === k ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                    }`}
                  >
                    {k} km
                  </button>
                ))}
              </div>
            </div>

            {/* Cost Breakdown */}
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-2 text-xs">
              <div className="flex items-center justify-between text-slate-600">
                <span>Cước mở cửa (2km đầu):</span>
                <span className="font-semibold text-slate-800">{fmtVND(simBase)}</span>
              </div>
              <div className="flex items-center justify-between text-slate-600">
                <span>Cước km tiếp theo ({Math.max(0, simDistance - 2)} km × {fmtVND(current.perKm)}):</span>
                <span className="font-semibold text-slate-800">{fmtVND(simNextKm)}</span>
              </div>
              {current.isPeakActive && (
                <div className="flex items-center justify-between text-orange-600 font-medium">
                  <span>Phụ phí Giờ cao điểm (x{current.peak}):</span>
                  <span>+{fmtVND(simRawTotal - simSubtotal)}</span>
                </div>
              )}
              <div className="pt-2 border-t border-slate-200 flex items-center justify-between">
                <span className="text-sm font-bold text-slate-800">Cước khách trả dự kiến:</span>
                <span className="text-base font-extrabold text-blue-600">{fmtVND(simTotal)}</span>
              </div>
            </div>

            {/* Revenue Distribution */}
            <div className="grid grid-cols-2 gap-3 text-xs">
              <div className="p-3 rounded-xl bg-blue-50/70 border border-blue-100">
                <span className="text-blue-700 block text-[11px]">Hoa hồng GoShip (15%):</span>
                <span className="text-sm font-bold text-blue-900 mt-0.5 block">{fmtVND(simCommission)}</span>
              </div>
              <div className="p-3 rounded-xl bg-emerald-50/70 border border-emerald-100">
                <span className="text-emerald-700 block text-[11px]">Tài xế thực nhận (85%):</span>
                <span className="text-sm font-bold text-emerald-900 mt-0.5 block">{fmtVND(simDriverNet)}</span>
              </div>
            </div>
          </div>

          {/* Quick Matrix Overview for all 4 vehicle types */}
          <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm">
            <h4 className="text-xs font-bold text-slate-600 uppercase tracking-wider mb-3">
              Bảng so sánh cước 4 Dòng xe
            </h4>
            <div className="space-y-2 text-xs">
              {Object.entries(localPricing).map(([key, item]) => {
                const isActive = activeVehicle === key;
                return (
                  <div
                    key={key}
                    onClick={() => setActiveVehicle(key)}
                    className={`p-2.5 rounded-xl border transition-all cursor-pointer flex items-center justify-between ${
                      isActive
                        ? 'border-blue-400 bg-blue-50/50'
                        : 'border-slate-100 hover:border-slate-200 bg-white'
                    }`}
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-base">{item.icon}</span>
                      <div>
                        <span className="font-semibold text-slate-800 block">{item.label}</span>
                        <span className="text-[11px] text-slate-400">Tối thiểu: {fmtVND(item.min)}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold text-slate-800">{fmtVND(item.base)}</div>
                      <div className="text-[11px] text-slate-500">+{fmtVND(item.perKm)}/km</div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── 6. TRANSACTIONS VIEW (IMPORTED FROM ./components/TransactionsView) ─────
// Includes correct COD/Non-COD ledger accounting, Payout Approvals and Pagination


// ─── MAIN APP WITH LIVE FIRESTORE POLLING & SYNC ──────────────────────────────

const NAV_ITEMS = [
  { key: 'dashboard', label: 'Tổng quan', icon: LayoutDashboard },
  { key: 'map', label: 'Bản đồ điều hành', icon: Map, badge: 'LIVE', badgeGreen: true },
  { key: 'orders', label: 'Quản lý đơn hàng', icon: Package },
  { key: 'drivers', label: 'Đối tác tài xế', icon: Users },
  { key: 'customers', label: 'Khách hàng CRM', icon: UserCheck },
  { key: 'pricing', label: 'Cấu hình bảng giá', icon: DollarSign },
  { key: 'transactions', label: 'Sổ cái & Rút tiền', icon: CreditCard },
  { key: 'vouchers', label: 'Khuyến mãi & Vouchers', icon: Tag },
  { key: 'incidents', label: 'Sự cố & SOS', icon: AlertTriangle },
];

export default function App() {
  const [loggedIn, setLoggedIn] = useState(false);
  const [activeNav, setActiveNav] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [drivers, setDrivers] = useState<DriverItem[]>([]);
  const [customers, setCustomers] = useState<CustomerItem[]>([]);
  const [vehicles, setVehicles] = useState<MapVehicleItem[]>([]);
  const [pricing, setPricing] = useState<Record<string, PricingRule>>(DEFAULT_PRICING);
  const [transactions, setTransactions] = useState<TransactionItem[]>([]);
  const [payoutRequests, setPayoutRequests] = useState<PayoutRequestItem[]>(DEFAULT_PAYOUTS);
  const [vouchers, setVouchers] = useState<VoucherItem[]>(DEFAULT_VOUCHERS);
  const [incidents, setIncidents] = useState<IncidentItem[]>(DEFAULT_INCIDENTS);
  const [lastSyncTime, setLastSyncTime] = useState<string>('Đang đồng bộ...');
  const [isSyncing, setIsSyncing] = useState<boolean>(false);

  const syncWithCloudFirestore = useCallback(async () => {
    setIsSyncing(true);
    try {
      const [
        cloudOrders,
        cloudTracking,
        cloudUsers,
        cloudWallets,
        cloudPricing,
        cloudPromotions,
        cloudIncidents,
        cloudPayouts,
      ] = await Promise.all([
        fetchCollection('orders', 150),
        fetchCollection('driver_tracking', 100),
        fetchCollection('users', 150),
        fetchCollection('driver_wallets', 100),
        fetchDocument('pricing_config', 'default'),
        fetchCollection('promotions', 50),
        fetchCollection('incidents', 50),
        fetchCollection('payout_requests', 50),
      ]);

      // 1. Real Orders from Cloud Firestore
      if (cloudOrders.length > 0) {
        const mappedOrders: OrderItem[] = cloudOrders.map((d) => {
          const code = String(d.orderCode || d.order_id || d._docId || '#GS');
          const displayId = code.startsWith('#') ? code : `#${code}`;
          const epod = Array.isArray(d.epod_photos) && d.epod_photos.length > 0
            ? String(d.epod_photos[0])
            : (d.epod_photo_url ? String(d.epod_photo_url) : null);

          let dropoffStr = 'Điểm giao hàng';
          if (Array.isArray(d.dropoff_addresses) && d.dropoff_addresses.length > 0) {
            dropoffStr = d.dropoff_addresses.join(' ➔ ');
          } else if (d.dropoff_address || d.dropoff) {
            dropoffStr = String(d.dropoff_address || d.dropoff);
          }

          let orderTime = 'Hôm nay';
          let orderDate = 'Hôm nay';
          if (d.created_at_millis) {
            const dt = new Date(Number(d.created_at_millis));
            orderTime = dt.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
            orderDate = dt.toLocaleDateString('vi-VN');
          } else if (d._UpdatedAt) {
            const dt = new Date(d._UpdatedAt);
            orderTime = dt.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
            orderDate = dt.toLocaleDateString('vi-VN');
          }

          return {
            id: displayId,
            docId: d._docId,
            customer: String(d.sender_name || d.customer_name || 'Khách hàng GoShip'),
            customerPhone: String(d.sender_phone || d.customer_phone || '---'),
            driver: String(d.assigned_driver_name || d.driver_name || 'Chưa nhận đơn'),
            driverPhone: String(d.driver_phone || d.assigned_driver_phone || '---'),
            vehicle: String(d.vehicle_name || d.vehicle_type || 'Xe Bán tải'),
            pickup: String(d.pickup_address || d.pickup || 'Điểm lấy hàng'),
            dropoff: dropoffStr,
            fee: Number(d.total_fee ?? d.total_price ?? d.original_fee ?? d.fee ?? 0),
            discount: Number(d.discount_amount ?? 0),
            paymentMethod: String(d.payment_method || 'Tiền mặt (COD)'),
            status: normalizeOrderStatus(d.status),
            time: orderTime,
            date: orderDate,
            podImg: epod,
            isCloud: true,
          };
        });
        mappedOrders.sort((a, b) => b.id.localeCompare(a.id));
        setOrders(mappedOrders);
      } else {
        setOrders([]);
      }

      // 2. Real Fleet Vehicles from `driver_tracking`
      if (cloudTracking.length > 0) {
        const onlineCloud = cloudTracking
          .filter(t => t.is_online !== false)
          .map((t): MapVehicleItem => {
            const activeOrd = t.active_order_id && t.active_order_id !== 'null' ? String(t.active_order_id) : undefined;
            return {
              id: t._docId,
              driver: String(t.driver_name || 'Tài xế GoShip'),
              phone: String(t.phone || '---'),
              vehicle: String(t.vehicle_type || t.vehicle_name || 'Xe Bán tải'),
              status: activeOrd ? 'delivering' : 'idle',
              lat: Number(t.lat ?? t.latitude ?? 10.7769),
              lng: Number(t.lng ?? t.longitude ?? 106.7009),
              plate: String(t.plate_number || t.plate || '---'),
              activeOrder: activeOrd,
              isCloud: true,
            };
          });
        setVehicles(onlineCloud);
      } else {
        setVehicles([]);
      }

      // 3. Real Drivers & Customers from `users` + `driver_tracking`
      const driverMap = new Map<string, DriverItem>();
      const customerList: CustomerItem[] = [];

      if (cloudUsers.length > 0) {
        cloudUsers.forEach((u) => {
          const role = String(u.role || '').toLowerCase();
          const isDriver = role === 'driver' ||
            String(u._docId).startsWith('drv_') ||
            Boolean(u.plateNumber) ||
            Boolean(u.vehicleType) ||
            String(u.name || '').toLowerCase().includes('driver');

          const rawSt = String(u.account_status || u.accountStatus || 'active');
          const st: 'active' | 'locked' | 'pending_approval' =
            rawSt === 'locked' ? 'locked' : rawSt === 'pending_approval' ? 'pending_approval' : 'active';

          if (isDriver) {
            const driverId = String(u.id || u._docId);
            driverMap.set(driverId, {
              id: driverId,
              docId: u._docId,
              name: String(u.name || 'Đối tác Tài xế'),
              phone: String(u.phone || '---'),
              email: String(u.email || 'driver@goship.vn'),
              vehicle: String(u.vehicleType || 'Xe Bán tải'),
              plate: String(u.plateNumber || '---'),
              rating: Number(u.rating ?? 5.0),
              orders: Number(u.totalOrders ?? 0),
              status: st,
              avatar: String(u.avatarUrl || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120'),
              joinDate: '2026',
              revenue: 0,
              cccd: u.cccd ? String(u.cccd) : undefined,
              cccdFrontUrl: u.cccdFrontUrl ? String(u.cccdFrontUrl) : undefined,
              cccdBackUrl: u.cccdBackUrl ? String(u.cccdBackUrl) : undefined,
              isCloud: true,
            });
          } else {
            // Customer Record
            const custOrders = cloudOrders.filter(o =>
              o.sender_phone === u.phone ||
              o.customer_phone === u.phone ||
              o.customer_name === u.name ||
              o.sender_name === u.name
            );
            const totalSpent = custOrders
              .filter(o => normalizeOrderStatus(o.status) === 'completed')
              .reduce((sum, o) => sum + Number(o.total_fee ?? o.fee ?? 0), 0);

            customerList.push({
              id: String(u.id || u._docId),
              docId: u._docId,
              name: String(u.name || u.displayName || 'Khách hàng GoShip'),
              phone: String(u.phone || '---'),
              email: String(u.email || 'customer@goship.vn'),
              status: rawSt === 'locked' ? 'locked' : 'active',
              totalOrders: custOrders.length,
              totalSpent,
              avatar: String(u.avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120'),
              joinDate: u._UpdatedAt ? new Date(u._UpdatedAt).toLocaleDateString('vi-VN') : '2026',
              address: String(u.address || ''),
              isCloud: true,
            });
          }
        });
      }

      // Merge drivers from tracking if not in users
      if (cloudTracking.length > 0) {
        cloudTracking.forEach((t) => {
          const trackId = String(t.driver_id || t._docId);
          if (!driverMap.has(trackId)) {
            driverMap.set(trackId, {
              id: trackId,
              docId: t._docId,
              name: String(t.driver_name || 'Tài xế GoShip'),
              phone: String(t.phone || '---'),
              email: 'driver@goship.vn',
              vehicle: String(t.vehicle_type || t.vehicle_name || 'Xe Bán tải'),
              plate: String(t.plate_number || t.plate || '---'),
              rating: 5.0,
              orders: 0,
              status: t.is_online ? 'active' : 'locked',
              avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=120',
              joinDate: '2026',
              revenue: 0,
              isCloud: true,
            });
          }
        });
      }

      setDrivers(Array.from(driverMap.values()));

      // Fallback customer if none found
      if (customerList.length > 0) {
        setCustomers(customerList);
      } else {
        setCustomers([
          {
            id: 'cust_01',
            docId: 'usr_cust_01',
            name: 'Nguyễn Văn An',
            phone: '0908123456',
            email: 'an.nguyen@goship.vn',
            status: 'active',
            totalOrders: 2,
            totalSpent: 350000,
            avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120',
            joinDate: '12/10/2026',
            isCloud: false,
          },
        ]);
      }

      // 4. Real Dynamic Pricing from `pricing_config/default`
      if (cloudPricing) {
        const mergedPricing: Record<string, PricingRule> = { ...DEFAULT_PRICING };
        for (const key of Object.keys(DEFAULT_PRICING)) {
          const r = cloudPricing[key];
          if (r && typeof r === 'object') {
            mergedPricing[key] = {
              ...DEFAULT_PRICING[key],
              base: Number(r.base ?? r.baseFee ?? DEFAULT_PRICING[key].base),
              perKm: Number(r.perKm ?? r.perKmFee ?? DEFAULT_PRICING[key].perKm),
              peak: Number(r.peak ?? r.peakMultiplier ?? DEFAULT_PRICING[key].peak),
              wait: Number(r.wait ?? r.waitFee ?? DEFAULT_PRICING[key].wait),
              min: Number(r.min ?? r.minFee ?? DEFAULT_PRICING[key].min),
              isPeakActive: Boolean(r.isPeakActive),
            };
          }
        }
        setPricing(mergedPricing);
      }

      // 5. Real Transactions with Correct Accounting (No double counting for COD!)
      const realTxList: TransactionItem[] = [];
      if (cloudWallets.length > 0) {
        cloudWallets.forEach((w) => {
          const driverName = String(w.driver_name || w._docId);
          const walletBal = Number(w.wallet_balance ?? 0);
          if (Array.isArray(w.transactions)) {
            w.transactions.forEach((t: any, idx: number) => {
              if (t && typeof t === 'object') {
                const title = String(t.title || 'Giao dịch ví');
                const rawAmt = String(t.amount || '0').replace(/[^\d-]/g, '');
                const numericAmt = parseInt(rawAmt, 10) || 0;
                const isPos = t.isPositive === true || String(t.amount || '').startsWith('+');
                const signedAmt = isPos ? Math.abs(numericAmt) : -Math.abs(numericAmt);
                let type: 'deposit' | 'withdraw' | 'commission' | 'refund' = 'deposit';
                const lower = title.toLowerCase();
                if (lower.includes('rút')) type = 'withdraw';
                else if (lower.includes('hoa hồng') || lower.includes('khấu trừ')) type = 'commission';
                realTxList.push({
                  id: `CLD-${w._docId.slice(0, 4).toUpperCase()}-${idx + 1}`,
                  driver: driverName,
                  driverId: w._docId,
                  type,
                  amount: signedAmt,
                  balance: walletBal,
                  time: String(t.time || 'Gần đây'),
                  status: 'completed',
                  note: title,
                  isCloud: true,
                });
              }
            });
          }
        });
      }

      if (cloudOrders.length > 0) {
        cloudOrders.forEach((o) => {
          const fee = Number(o.total_fee ?? o.total_price ?? o.fee ?? 0);
          if (normalizeOrderStatus(o.status) === 'completed' && fee > 0) {
            const orderCode = String(o.orderCode || o.order_id || o._docId);
            const driverName = String(o.assigned_driver_name || o.driver_name || 'Tài xế GoShip');
            const comm = Math.round(fee * 0.15);
            const net = fee - comm;
            const isCod = String(o.payment_method || '').toLowerCase().includes('cod') ||
                          String(o.payment_method || '').toLowerCase().includes('tiền mặt');

            // Ghi nhận khấu trừ 15% hoa hồng sàn
            realTxList.push({
              id: `TXN-${orderCode}-COMM`,
              driver: driverName,
              driverId: String(o.assigned_driver_id || 'DRV'),
              type: 'commission',
              amount: -comm,
              balance: 0,
              time: o._UpdatedAt ? new Date(o._UpdatedAt).toLocaleString('vi-VN') : 'Gần đây',
              status: 'completed',
              note: `Khấu trừ 15% hoa hồng đơn ${orderCode} (${isCod ? 'Thu tiền mặt COD' : 'Trả trước'})`,
              isCloud: true,
            });

            // CHỈ cộng 85% cước vào ví tài xế khi khách thanh toán điện tử (Non-COD)
            // Đơn COD: Tài xế đã cầm trọn tiền mặt, không cộng số dư ví để tránh nhận tiền 2 lần!
            if (!isCod) {
              realTxList.push({
                id: `TXN-${orderCode}-EARN`,
                driver: driverName,
                driverId: String(o.assigned_driver_id || 'DRV'),
                type: 'deposit',
                amount: net,
                balance: net,
                time: o._UpdatedAt ? new Date(o._UpdatedAt).toLocaleString('vi-VN') : 'Gần đây',
                status: 'completed',
                note: `Giải ngân cước chuyến đi đơn ${orderCode} (Thanh toán điện tử 85%)`,
                isCloud: true,
              });
            }
          }
        });
      }

      setTransactions(realTxList.reverse());

      // 6. Vouchers / Promotions
      if (cloudPromotions.length > 0) {
        setVouchers(
          cloudPromotions.map((p) => ({
            id: p._docId,
            docId: p._docId,
            code: String(p.code || 'PROMO').toUpperCase(),
            discountPercent: p.discountPercent !== undefined ? Number(p.discountPercent) : undefined,
            discountAmount: p.discountAmount !== undefined ? Number(p.discountAmount) : undefined,
            maxDiscount: Number(p.maxDiscount ?? 50000),
            minOrder: Number(p.minOrder ?? 50000),
            usageLimit: Number(p.usageLimit ?? 100),
            usedCount: Number(p.usedCount ?? 0),
            expiryDate: String(p.expiryDate ?? '2026-12-31'),
            isActive: p.isActive !== false,
            description: String(p.description || ''),
            isCloud: true,
          }))
        );
      } else {
        setVouchers(DEFAULT_VOUCHERS);
      }

      // 7. Incidents / SOS Hub
      if (cloudIncidents.length > 0) {
        setIncidents(
          cloudIncidents.map((i) => ({
            id: String(i.id || i._docId),
            docId: i._docId,
            orderId: String(i.orderId || i.order_id || '#GS-000'),
            driverName: String(i.driverName || i.driver_name || 'Tài xế GoShip'),
            customerName: String(i.customerName || i.customer_name || 'Khách hàng'),
            type: (i.type || 'sos') as any,
            status: (i.status || 'pending') as any,
            description: String(i.description || 'Sự cố chuyến đi'),
            time: String(i.time || 'Gần đây'),
            location: i.location ? String(i.location) : undefined,
            severity: (i.severity || 'high') as any,
            isCloud: true,
          }))
        );
      } else {
        setIncidents(DEFAULT_INCIDENTS);
      }

      // 8. Payout Requests
      if (cloudPayouts.length > 0) {
        setPayoutRequests(
          cloudPayouts.map((p) => ({
            id: String(p.id || p._docId),
            docId: p._docId,
            driverId: String(p.driverId || p.driver_id || ''),
            driverName: String(p.driverName || p.driver_name || 'Tài xế GoShip'),
            driverPhone: String(p.driverPhone || p.phone || '---'),
            amount: Number(p.amount ?? 0),
            bankName: String(p.bankName || p.bank_name || 'Vietcombank'),
            accountNo: String(p.accountNo || p.account_no || '---'),
            holderName: String(p.holderName || p.holder_name || '---'),
            time: String(p.time || 'Hôm nay'),
            status: (p.status || 'pending') as any,
            rejectionReason: p.rejectionReason ? String(p.rejectionReason) : undefined,
            isCloud: true,
          }))
        );
      } else {
        setPayoutRequests(DEFAULT_PAYOUTS);
      }

      setLastSyncTime(new Date().toLocaleTimeString('vi-VN'));
    } finally {
      setIsSyncing(false);
    }
  }, []);

  useEffect(() => {
    syncWithCloudFirestore();
    const timer = setInterval(syncWithCloudFirestore, 6000);
    return () => clearInterval(timer);
  }, [syncWithCloudFirestore]);

  // Order status update with safe driver GPS release
  const handleUpdateOrderStatus = async (order: OrderItem, newStatus: 'completed' | 'cancelled' | 'in_transit') => {
    setOrders(prev => prev.map(o => (o.id === order.id ? { ...o, status: newStatus } : o)));
    await patchDocumentFields('orders', order.docId, {
      status: newStatus,
    });

    // Release driver from delivering in driver_tracking
    if (newStatus === 'completed' || newStatus === 'cancelled') {
      const vehicleToRelease = vehicles.find(v =>
        v.activeOrder === order.id ||
        v.driver === order.driver ||
        v.phone === order.driverPhone
      );
      if (vehicleToRelease) {
        await patchDocumentFields('driver_tracking', vehicleToRelease.id, {
          active_order_id: null,
          status: 'idle',
        });
      }
    }
    await syncWithCloudFirestore();
  };

  // Manual Dispatch Driver to Pending Order
  const handleManualDispatchOrder = async (order: OrderItem, driver: DriverItem) => {
    setOrders(prev => prev.map(o => o.id === order.id ? {
      ...o,
      status: 'in_transit',
      driver: driver.name,
      driverPhone: driver.phone,
      vehicle: driver.vehicle,
    } : o));

    await patchDocumentFields('orders', order.docId, {
      status: 'in_transit',
      assigned_driver_id: driver.id,
      assigned_driver_name: driver.name,
      assigned_driver_phone: driver.phone,
      assigned_driver_plate: driver.plate,
      vehicle_name: driver.vehicle,
      dispatch_type: 'MANUAL_ADMIN',
      dispatched_at: new Date().toISOString(),
    });

    await patchDocumentFields('driver_tracking', driver.docId, {
      active_order_id: order.id,
      status: 'delivering',
    });

    await syncWithCloudFirestore();
  };

  // Driver Status Update with Safe Active Trip Check
  const handleUpdateDriverStatus = async (driver: DriverItem, newStatus: 'active' | 'locked') => {
    if (newStatus === 'locked') {
      const isDelivering = vehicles.some(v => (v.id === driver.docId || v.id === driver.id) && v.status === 'delivering');
      const hasActiveOrder = orders.some(o => (o.driver === driver.name || o.driverPhone === driver.phone) && o.status === 'in_transit');
      if (isDelivering || hasActiveOrder) {
        const confirmLock = window.confirm(
          `⚠️ CẢNH BÁO AN TOÀN:\n\nTài xế ${driver.name} hiện đang thực hiện chuyến hàng dở dang!\nNếu khóa ngay lúc này, vị trí GPS sẽ bị xóa và chuyến hàng sẽ mất dấu.\n\nBạn có chắc chắn muốn buộc khóa tài khoản không?`
        );
        if (!confirmLock) return;
      }
    }

    setDrivers(prev => prev.map(d => (d.docId === driver.docId ? { ...d, status: newStatus } : d)));
    if (driver.isCloud) {
      await patchDocumentFields('users', driver.docId, {
        account_status: newStatus,
        accountStatus: newStatus,
      });
      if (newStatus === 'locked') {
        await deleteDocument('driver_tracking', driver.docId);
        await deleteDocument('driver_tracking', driver.id);
        await deleteDocument('online_drivers', driver.docId);
      }
      await syncWithCloudFirestore();
    }
  };

  // Customer Status Update
  const handleUpdateCustomerStatus = async (customer: CustomerItem, newStatus: 'active' | 'locked') => {
    setCustomers(prev => prev.map(c => c.docId === customer.docId ? { ...c, status: newStatus } : c));
    await patchDocumentFields('users', customer.docId, {
      account_status: newStatus,
      accountStatus: newStatus,
    });
    await syncWithCloudFirestore();
  };

  // Pricing Update
  const handleSavePricing = async (newPricing: Record<string, PricingRule>): Promise<boolean> => {
    setPricing(newPricing);
    const payload: Record<string, any> = {};
    for (const [k, v] of Object.entries(newPricing)) {
      payload[k] = {
        key: k,
        name: v.label,
        icon: v.icon,
        base: v.base,
        perKm: v.perKm,
        peak: v.peak,
        wait: v.wait,
        min: v.min,
        isPeakActive: v.isPeakActive,
      };
    }
    return patchDocumentFields('pricing_config', 'default', payload);
  };

  // Voucher Management
  const handleCreateVoucher = async (voucher: Omit<VoucherItem, 'id' | 'docId'>): Promise<boolean> => {
    const docId = `voucher_${voucher.code.toLowerCase()}`;
    const ok = await createDocument('promotions', docId, {
      ...voucher,
      created_at: new Date().toISOString(),
    });
    if (ok) {
      await syncWithCloudFirestore();
    }
    return ok;
  };

  const handleToggleVoucher = async (voucher: VoucherItem) => {
    const nextActive = !voucher.isActive;
    setVouchers(prev => prev.map(v => v.code === voucher.code ? { ...v, isActive: nextActive } : v));
    await patchDocumentFields('promotions', voucher.docId, {
      isActive: nextActive,
    });
    await syncWithCloudFirestore();
  };

  const handleDeleteVoucher = async (voucher: VoucherItem) => {
    setVouchers(prev => prev.filter(v => v.code !== voucher.code));
    await deleteDocument('promotions', voucher.docId);
    await syncWithCloudFirestore();
  };

  // Incident Management
  const handleResolveIncident = async (incident: IncidentItem) => {
    setIncidents(prev => prev.map(i => i.id === incident.id ? { ...i, status: 'resolved' } : i));
    await patchDocumentFields('incidents', incident.docId, {
      status: 'resolved',
      resolved_at: new Date().toISOString(),
    });
    await syncWithCloudFirestore();
  };

  // Payout Approvals
  const handleApprovePayout = async (payout: PayoutRequestItem) => {
    setPayoutRequests(prev => prev.map(p => p.id === payout.id ? { ...p, status: 'approved' } : p));
    await patchDocumentFields('payout_requests', payout.docId, {
      status: 'approved',
      approved_at: new Date().toISOString(),
    });
    await syncWithCloudFirestore();
  };

  const handleRejectPayout = async (payout: PayoutRequestItem, reason: string) => {
    setPayoutRequests(prev => prev.map(p => p.id === payout.id ? { ...p, status: 'rejected', rejectionReason: reason } : p));
    await patchDocumentFields('payout_requests', payout.docId, {
      status: 'rejected',
      rejection_reason: reason,
      rejected_at: new Date().toISOString(),
    });
    await syncWithCloudFirestore();
  };

  if (!loggedIn) {
    return <LoginScreen onLogin={() => setLoggedIn(true)} />;
  }

  const currentPage = NAV_ITEMS.find(n => n.key === activeNav);
  const pendingIncidentsCount = incidents.filter(i => i.status !== 'resolved').length;

  return (
    <div className="flex h-screen w-full overflow-hidden" style={{ backgroundColor: '#F7F9FC' }}>
      <aside
        className={`flex flex-col shrink-0 bg-white border-r border-slate-100 shadow-sm transition-all duration-300 ${
          sidebarOpen ? 'w-64' : 'w-16'
        }`}
      >
        {sidebarOpen ? (
          <div className="flex items-center gap-3 px-4 py-5 border-b border-slate-100">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0 shadow-sm" style={{ background: '#2563EB' }}>
              <Truck className="w-5 h-5 text-white" />
            </div>
            <div className="overflow-hidden flex-1">
              <div className="font-bold text-slate-800 text-sm leading-tight">GoShip Admin</div>
              <div className="text-xs text-emerald-600 font-semibold leading-tight">Cloud Firestore Sync</div>
            </div>
            <button
              onClick={() => setSidebarOpen(false)}
              className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors cursor-pointer"
              title="Thu nhỏ thanh điều hướng"
            >
              <Menu className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-4 border-b border-slate-100 gap-2">
            <button
              onClick={() => setSidebarOpen(true)}
              className="w-10 h-10 rounded-xl flex items-center justify-center bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white transition-all shadow-xs cursor-pointer group"
              title="Nhấn để mở rộng thanh điều hướng"
            >
              <ChevronRight className="w-5 h-5 group-hover:translate-x-0.5 transition-transform" />
            </button>
          </div>
        )}

        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {NAV_ITEMS.map(item => {
            const Icon = item.icon;
            const active = activeNav === item.key;
            const showBadge = item.key === 'incidents' && pendingIncidentsCount > 0 ? `${pendingIncidentsCount}` : item.badge;

            return (
              <button
                key={item.key}
                onClick={() => setActiveNav(item.key)}
                title={!sidebarOpen ? item.label : undefined}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all cursor-pointer ${
                  active
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-800'
                }`}
              >
                <Icon className="w-4 h-4 shrink-0" />
                {sidebarOpen && <span className="truncate flex-1 text-left">{item.label}</span>}
                {sidebarOpen && showBadge && (
                  <span className={`px-1.5 py-0.5 rounded-full text-xs font-semibold ${
                    item.key === 'incidents'
                      ? 'bg-red-500 text-white animate-pulse'
                      : active
                      ? 'bg-white/20 text-white'
                      : 'bg-emerald-100 text-emerald-700'
                  }`}>
                    {showBadge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        <div className="p-3 border-t border-slate-100">
          <div className={`flex items-center gap-3 px-2 py-2 rounded-xl ${sidebarOpen ? '' : 'justify-center'}`}>
            <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
              AD
            </div>
            {sidebarOpen && (
              <div className="flex-1 min-w-0">
                <div className="text-xs font-semibold text-slate-800 truncate">Admin GoShip</div>
                <div className="text-xs text-slate-400 truncate">admin@goship.vn</div>
              </div>
            )}
            {sidebarOpen && (
              <button
                onClick={() => setLoggedIn(false)}
                className="p-1.5 rounded-lg hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors cursor-pointer"
                title="Đăng xuất"
              >
                <LogOut className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <header className="bg-white border-b border-slate-100 px-6 py-3.5 flex items-center justify-between gap-4 shrink-0 shadow-xs">
          <div>
            <h1 className="text-slate-800 font-bold text-lg leading-tight">{currentPage?.label}</h1>
            <p className="text-xs text-slate-400">
              Đồng bộ trực tiếp với Firebase Cloud Firestore (`goship-145a0`) • Cập nhật lúc: {lastSyncTime}
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={syncWithCloudFirestore}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-50 border border-blue-200 text-xs text-blue-700 font-semibold hover:bg-blue-100 transition-colors"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`} />
              Làm mới Cloud
            </button>

            <div className="hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 border border-emerald-200 text-xs text-emerald-700 font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              {vehicles.length} xe trực tuyến
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {activeNav === 'dashboard' && (
            <DashboardView
              orders={orders}
              vehicles={vehicles}
              incidents={incidents}
              onNavigate={setActiveNav}
            />
          )}
          {activeNav === 'map' && <FleetMapView vehicles={vehicles} />}
          {activeNav === 'orders' && (
            <OrdersView
              orders={orders}
              drivers={drivers}
              vehicles={vehicles}
              onUpdateOrderStatus={handleUpdateOrderStatus}
              onManualDispatch={handleManualDispatchOrder}
            />
          )}
          {activeNav === 'drivers' && (
            <DriversView drivers={drivers} onUpdateDriverStatus={handleUpdateDriverStatus} />
          )}
          {activeNav === 'customers' && (
            <CustomersView
              customers={customers}
              orders={orders}
              onUpdateCustomerStatus={handleUpdateCustomerStatus}
            />
          )}
          {activeNav === 'pricing' && (
            <PricingView pricing={pricing} onSavePricing={handleSavePricing} />
          )}
          {activeNav === 'transactions' && (
            <TransactionsView
              transactions={transactions}
              payoutRequests={payoutRequests}
              onApprovePayout={handleApprovePayout}
              onRejectPayout={handleRejectPayout}
            />
          )}
          {activeNav === 'vouchers' && (
            <VouchersView
              vouchers={vouchers}
              onCreateVoucher={handleCreateVoucher}
              onToggleVoucher={handleToggleVoucher}
              onDeleteVoucher={handleDeleteVoucher}
            />
          )}
          {activeNav === 'incidents' && (
            <IncidentsView
              incidents={incidents}
              orders={orders}
              onResolveIncident={handleResolveIncident}
              onNavigateToOrder={(orderId) => {
                setActiveNav('orders');
              }}
            />
          )}
        </main>
      </div>
    </div>
  );
}
