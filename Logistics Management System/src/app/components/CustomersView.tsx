import React, { useState } from 'react';
import {
  Users, Search, Lock, Unlock, Eye, X, CheckCircle,
  Package, DollarSign, Phone, Mail, Calendar, ShieldAlert
} from 'lucide-react';
import { CustomerItem, OrderItem } from '../types';

interface CustomersViewProps {
  customers: CustomerItem[];
  orders: OrderItem[];
  onUpdateCustomerStatus: (customer: CustomerItem, newStatus: 'active' | 'locked') => Promise<void>;
}

export function CustomersView({
  customers,
  orders,
  onUpdateCustomerStatus,
}: CustomersViewProps) {
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'locked'>('all');
  const [search, setSearch] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerItem | null>(null);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const activeCount = customers.filter(c => c.status === 'active').length;
  const lockedCount = customers.filter(c => c.status === 'locked').length;

  const filtered = customers.filter(c => {
    const matchStatus = statusFilter === 'all' || c.status === statusFilter;
    const q = search.toLowerCase();
    const matchSearch =
      c.name.toLowerCase().includes(q) ||
      c.phone.includes(search) ||
      c.email.toLowerCase().includes(q);
    return matchStatus && matchSearch;
  });

  const totalPages = Math.ceil(filtered.length / pageSize) || 1;
  const paginatedList = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const customerOrders = selectedCustomer
    ? orders.filter(
        o =>
          o.customerPhone === selectedCustomer.phone ||
          o.customer.toLowerCase() === selectedCustomer.name.toLowerCase()
      )
    : [];

  const fmtVND = (amt: number) => {
    return amt.toLocaleString('vi-VN') + ' đ';
  };

  const handleToggleStatus = async (customer: CustomerItem) => {
    const newStatus = customer.status === 'active' ? 'locked' : 'active';
    const confirmMsg =
      newStatus === 'locked'
        ? `Bạn có chắc chắn muốn KHÓA tài khoản khách hàng "${customer.name}"? Khách sẽ không thể đặt chuyến mới.`
        : `Mở khóa cho tài khoản khách hàng "${customer.name}"?`;
    if (!window.confirm(confirmMsg)) return;

    setUpdatingId(customer.docId);
    try {
      await onUpdateCustomerStatus(customer, newStatus);
    } finally {
      setUpdatingId(null);
    }
  };

  return (
    <div className="space-y-5">
      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-500 font-medium">Tổng số khách hàng</p>
            <p className="text-2xl font-bold text-slate-800 mt-1">{customers.length}</p>
            <p className="text-xs text-blue-600 font-medium mt-1">Đồng bộ từ Cloud Firestore</p>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-blue-50 flex items-center justify-center text-blue-600">
            <Users className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-500 font-medium">Khách hàng hoạt động</p>
            <p className="text-2xl font-bold text-emerald-600 mt-1">{activeCount}</p>
            <p className="text-xs text-emerald-600 font-medium mt-1">Đủ điều kiện tạo đơn</p>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-emerald-50 flex items-center justify-center text-emerald-600">
            <CheckCircle className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-500 font-medium">Khách bị chặn / Khóa</p>
            <p className="text-2xl font-bold text-red-600 mt-1">{lockedCount}</p>
            <p className="text-xs text-red-500 font-medium mt-1">Vi phạm chính sách / Boom hàng</p>
          </div>
          <div className="w-12 h-12 rounded-2xl bg-red-50 flex items-center justify-center text-red-600">
            <ShieldAlert className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-1.5">
          {[
            { key: 'all', label: `Tất cả (${customers.length})` },
            { key: 'active', label: `Đang hoạt động (${activeCount})` },
            { key: 'locked', label: `Bị khóa (${lockedCount})` },
          ].map(f => (
            <button
              key={f.key}
              onClick={() => {
                setStatusFilter(f.key as any);
                setCurrentPage(1);
              }}
              className={`px-3.5 py-2 rounded-xl text-xs font-semibold transition-all ${
                statusFilter === f.key
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>

        <div className="relative flex-1 min-w-56 max-w-sm">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Tìm theo tên khách hàng, số điện thoại, email..."
            value={search}
            onChange={e => {
              setSearch(e.target.value);
              setCurrentPage(1);
            }}
            className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
          />
        </div>
      </div>

      {/* Customers Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/70">
                <th className="text-left px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Khách hàng</th>
                <th className="text-left px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Thông tin liên hệ</th>
                <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Số đơn đã đặt</th>
                <th className="text-right px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Tổng chi tiêu (LTV)</th>
                <th className="text-center px-4 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Trạng thái</th>
                <th className="text-center px-5 py-3.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {paginatedList.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-12 text-center text-slate-400">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <Users className="w-8 h-8 text-slate-300" />
                      <p className="text-sm font-medium text-slate-600">Không tìm thấy khách hàng nào</p>
                      <p className="text-xs text-slate-400">Khách hàng đăng ký trên App Mobile sẽ tự động đồng bộ vào Cloud Firestore.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedList.map(cust => (
                  <tr key={cust.docId} className="hover:bg-slate-50/60 transition-colors">
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-3">
                        <img
                          src={cust.avatar}
                          alt={cust.name}
                          className="w-10 h-10 rounded-full object-cover ring-2 ring-slate-100"
                        />
                        <div>
                          <div className="font-semibold text-slate-800 flex items-center gap-1.5">
                            {cust.name}
                            {cust.isCloud && (
                              <span className="px-1.5 py-0.5 text-[10px] font-bold bg-blue-50 text-blue-600 rounded">CLOUD</span>
                            )}
                          </div>
                          <div className="text-xs text-slate-400">Tham gia: {cust.joinDate}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-4">
                      <div className="text-slate-800 font-medium flex items-center gap-1">
                        <Phone className="w-3.5 h-3.5 text-slate-400" /> {cust.phone}
                      </div>
                      <div className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                        <Mail className="w-3.5 h-3.5 text-slate-400" /> {cust.email}
                      </div>
                    </td>
                    <td className="px-4 py-4 text-center">
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-50 text-blue-700">
                        <Package className="w-3 h-3" /> {cust.totalOrders} đơn
                      </span>
                    </td>
                    <td className="px-4 py-4 text-right">
                      <span className="font-bold text-slate-800">{fmtVND(cust.totalSpent)}</span>
                    </td>
                    <td className="px-4 py-4 text-center">
                      {cust.status === 'active' ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700">
                          <CheckCircle className="w-3 h-3" /> Hoạt động
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-red-50 text-red-600">
                          <Lock className="w-3 h-3" /> Bị khóa
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-4 text-center">
                      <div className="inline-flex items-center gap-1.5">
                        <button
                          onClick={() => setSelectedCustomer(cust)}
                          className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                          title="Xem lịch sử chuyến hàng"
                        >
                          <Eye className="w-3.5 h-3.5" /> Lịch sử đơn
                        </button>

                        <button
                          disabled={updatingId === cust.docId}
                          onClick={() => handleToggleStatus(cust)}
                          className={`inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                            cust.status === 'active'
                              ? 'bg-red-50 text-red-600 hover:bg-red-100'
                              : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                          }`}
                        >
                          {cust.status === 'active' ? (
                            <>
                              <Lock className="w-3.5 h-3.5" /> Khóa
                            </>
                          ) : (
                            <>
                              <Unlock className="w-3.5 h-3.5" /> Mở
                            </>
                          )}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {filtered.length > 0 && (
          <div className="px-5 py-3.5 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3 text-xs text-slate-500">
            <div className="flex items-center gap-2">
              <span>Hiển thị</span>
              <select
                value={pageSize}
                onChange={e => {
                  setPageSize(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="bg-slate-50 border border-slate-200 rounded-lg px-2 py-1 text-xs focus:outline-none"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
              </select>
              <span>trên tổng số {filtered.length} khách hàng</span>
            </div>

            <div className="flex items-center gap-1">
              <button
                disabled={currentPage <= 1}
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
              >
                Trước
              </button>
              <span className="px-3 py-1 font-semibold text-slate-800">
                {currentPage} / {totalPages}
              </span>
              <button
                disabled={currentPage >= totalPages}
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                className="px-2.5 py-1 rounded-lg border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
              >
                Sau
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Customer Order History Modal */}
      {selectedCustomer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-2xl w-full shadow-2xl border border-slate-100 overflow-hidden max-h-[90vh] flex flex-col">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <img
                  src={selectedCustomer.avatar}
                  alt=""
                  className="w-12 h-12 rounded-full object-cover ring-2 ring-blue-100"
                />
                <div>
                  <h3 className="font-bold text-slate-800 text-base">{selectedCustomer.name}</h3>
                  <p className="text-xs text-slate-400">
                    {selectedCustomer.phone} • {selectedCustomer.email}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedCustomer(null)}
                className="p-2 rounded-xl hover:bg-slate-100 text-slate-400"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-4">
              <div className="grid grid-cols-3 gap-3">
                <div className="bg-blue-50 p-3.5 rounded-2xl">
                  <div className="text-xs text-blue-600 font-medium">Tổng số đơn</div>
                  <div className="text-lg font-bold text-blue-800 mt-0.5">{customerOrders.length} đơn</div>
                </div>
                <div className="bg-emerald-50 p-3.5 rounded-2xl">
                  <div className="text-xs text-emerald-600 font-medium">Tổng chi tiêu</div>
                  <div className="text-lg font-bold text-emerald-800 mt-0.5">
                    {fmtVND(customerOrders.reduce((sum, o) => sum + o.fee, 0))}
                  </div>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-2xl">
                  <div className="text-xs text-slate-500 font-medium">Trạng thái</div>
                  <div className="text-sm font-bold text-slate-800 mt-1">
                    {selectedCustomer.status === 'active' ? 'Hoạt động' : 'Bị khóa'}
                  </div>
                </div>
              </div>

              <div>
                <h4 className="text-xs font-bold text-slate-600 uppercase tracking-wider mb-2">
                  Lịch sử các chuyến hàng gần nhất
                </h4>
                {customerOrders.length === 0 ? (
                  <div className="py-8 text-center text-slate-400 border border-dashed rounded-2xl">
                    Chưa có đơn hàng nào được tạo bởi khách hàng này.
                  </div>
                ) : (
                  <div className="space-y-2">
                    {customerOrders.map(order => (
                      <div
                        key={order.id}
                        className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/50 flex items-center justify-between gap-3 text-xs"
                      >
                        <div>
                          <div className="font-semibold text-blue-600 flex items-center gap-1.5">
                            {order.id}
                            <span className="text-slate-400 font-normal">· {order.time} {order.date}</span>
                          </div>
                          <div className="text-slate-600 mt-1 line-clamp-1">
                            📍 {order.pickup} ➔ 🏁 {order.dropoff}
                          </div>
                          <div className="text-slate-400 mt-0.5">
                            Tài xế: {order.driver} ({order.vehicle})
                          </div>
                        </div>
                        <div className="text-right shrink-0">
                          <div className="font-bold text-slate-800">{fmtVND(order.fee)}</div>
                          <div className="text-[11px] text-emerald-600 font-medium mt-0.5">
                            {order.status === 'completed'
                              ? 'Hoàn thành'
                              : order.status === 'in_transit'
                              ? 'Đang giao'
                              : order.status === 'cancelled'
                              ? 'Đã hủy'
                              : 'Chờ nhận'}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
