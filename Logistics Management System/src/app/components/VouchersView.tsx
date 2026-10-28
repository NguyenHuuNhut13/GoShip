import React, { useState } from 'react';
import {
  Tag, Plus, CheckCircle, Clock, Trash2, Power, Search,
  Percent, DollarSign, Calendar, AlertCircle, X
} from 'lucide-react';
import { VoucherItem } from '../types';

interface VouchersViewProps {
  vouchers: VoucherItem[];
  onCreateVoucher: (voucher: Omit<VoucherItem, 'id' | 'docId'>) => Promise<boolean>;
  onToggleVoucher: (voucher: VoucherItem) => Promise<void>;
  onDeleteVoucher: (voucher: VoucherItem) => Promise<void>;
}

export function VouchersView({
  vouchers,
  onCreateVoucher,
  onToggleVoucher,
  onDeleteVoucher,
}: VouchersViewProps) {
  const [search, setSearch] = useState('');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // Form states
  const [code, setCode] = useState('');
  const [discountType, setDiscountType] = useState<'percent' | 'fixed'>('percent');
  const [discountValue, setDiscountValue] = useState<number>(20);
  const [maxDiscount, setMaxDiscount] = useState<number>(50000);
  const [minOrder, setMinOrder] = useState<number>(100000);
  const [usageLimit, setUsageLimit] = useState<number>(100);
  const [expiryDate, setExpiryDate] = useState('2026-12-31');
  const [description, setDescription] = useState('');

  const activeCount = vouchers.filter(v => v.isActive).length;

  const filtered = vouchers.filter(v =>
    v.code.toLowerCase().includes(search.toLowerCase()) ||
    v.description.toLowerCase().includes(search.toLowerCase())
  );

  const fmtVND = (amt: number) => amt.toLocaleString('vi-VN') + ' đ';

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!code.trim()) {
      alert('Vui lòng nhập mã khuyến mãi!');
      return;
    }
    setSubmitting(true);
    try {
      const payload: Omit<VoucherItem, 'id' | 'docId'> = {
        code: code.trim().toUpperCase(),
        discountPercent: discountType === 'percent' ? discountValue : undefined,
        discountAmount: discountType === 'fixed' ? discountValue : undefined,
        maxDiscount,
        minOrder,
        usageLimit,
        usedCount: 0,
        expiryDate,
        isActive: true,
        description: description || `Mã giảm giá ${code.toUpperCase()} cho chuyến xe GoShip`,
        isCloud: true,
      };

      const ok = await onCreateVoucher(payload);
      if (ok) {
        setShowCreateModal(false);
        setCode('');
        setDescription('');
      } else {
        alert('Không thể lưu mã lên Cloud. Vui lòng thử lại!');
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-5">
      {/* KPI & Create Action */}
      <div className="bg-white rounded-2xl p-5 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-slate-800 font-bold text-lg flex items-center gap-2">
            <Tag className="w-5 h-5 text-blue-600" /> Quản lý Mã khuyến mãi & Ưu đãi cước xe
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Đồng bộ trực tiếp với App Khách hàng qua Cloud Firestore • Khách nhập mã tại Bước 3 Xác nhận giá
          </p>
        </div>

        <button
          onClick={() => setShowCreateModal(true)}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-semibold bg-blue-600 text-white hover:bg-blue-700 shadow-sm transition-all"
        >
          <Plus className="w-4 h-4" /> Tạo mã khuyến mãi mới
        </button>
      </div>

      {/* Filter and Search */}
      <div className="bg-white rounded-2xl p-4 border border-slate-100 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2 text-xs text-slate-500">
          <span className="font-semibold text-slate-800">{vouchers.length}</span> mã trong hệ thống ·
          <span className="font-semibold text-emerald-600">{activeCount}</span> đang kích hoạt
        </div>

        <div className="relative flex-1 min-w-56 max-w-sm">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Tìm theo mã voucher (TRUCK50, FREESHIP...)"
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500"
          />
        </div>
      </div>

      {/* Vouchers Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filtered.map(v => {
          const isPercent = v.discountPercent !== undefined && v.discountPercent > 0;
          return (
            <div
              key={v.docId || v.code}
              className={`bg-white rounded-2xl p-5 border transition-all relative overflow-hidden flex flex-col justify-between ${
                v.isActive
                  ? 'border-slate-200 shadow-sm hover:shadow-md'
                  : 'border-slate-100 opacity-60 bg-slate-50/50'
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div
                    className={`w-12 h-12 rounded-2xl flex items-center justify-center font-bold text-lg shrink-0 ${
                      v.isActive
                        ? 'bg-blue-50 text-blue-600 border border-blue-200'
                        : 'bg-slate-100 text-slate-400'
                    }`}
                  >
                    {isPercent ? `${v.discountPercent}%` : 'VNĐ'}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-base text-slate-800 tracking-wider">
                        {v.code}
                      </span>
                      {v.isActive ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-600">
                          ĐANG CHẠY
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-200 text-slate-600">
                          TẠM DỪNG
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-slate-500 mt-1 line-clamp-1">{v.description}</p>
                  </div>
                </div>
              </div>

              <div className="my-4 py-3 border-y border-dashed border-slate-100 space-y-1.5 text-xs">
                <div className="flex justify-between text-slate-600">
                  <span>Mức giảm:</span>
                  <span className="font-bold text-slate-800">
                    {isPercent ? `Giảm ${v.discountPercent}% (Tối đa ${fmtVND(v.maxDiscount)})` : `Giảm ${fmtVND(v.discountAmount || 0)}`}
                  </span>
                </div>
                <div className="flex justify-between text-slate-600">
                  <span>Đơn tối thiểu:</span>
                  <span className="font-medium text-slate-800">{fmtVND(v.minOrder)}</span>
                </div>
                <div className="flex justify-between text-slate-600">
                  <span>Lượt sử dụng:</span>
                  <span className="font-medium text-slate-800">
                    {v.usedCount} / {v.usageLimit} lượt
                  </span>
                </div>
                <div className="flex justify-between text-slate-600">
                  <span>Hạn sử dụng:</span>
                  <span className="font-medium text-slate-800">{v.expiryDate}</span>
                </div>
              </div>

              <div className="flex items-center justify-between gap-2 pt-1">
                <button
                  onClick={() => onToggleVoucher(v)}
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${
                    v.isActive
                      ? 'bg-amber-50 text-amber-700 hover:bg-amber-100'
                      : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                  }`}
                >
                  <Power className="w-3.5 h-3.5" />
                  {v.isActive ? 'Tắt voucher' : 'Kích hoạt lại'}
                </button>

                <button
                  onClick={() => {
                    if (window.confirm(`Xóa vĩnh viễn mã khuyến mãi ${v.code}?`)) {
                      onDeleteVoucher(v);
                    }
                  }}
                  className="p-1.5 rounded-xl text-slate-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                  title="Xóa voucher"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Modal Tạo Voucher Mới */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-100 overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
              <h3 className="font-bold text-slate-800 text-base flex items-center gap-2">
                <Plus className="w-4 h-4 text-blue-600" /> Tạo mã khuyến mãi mới
              </h3>
              <button
                onClick={() => setShowCreateModal(false)}
                className="p-2 rounded-xl hover:bg-slate-100 text-slate-400"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreate} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Mã khuyến mãi (Code)</label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: TRUCK50, GOSHIPHE2026..."
                  value={code}
                  onChange={e => setCode(e.target.value.toUpperCase())}
                  className="w-full px-3.5 py-2.5 text-sm uppercase font-mono font-bold bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/30"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Hình thức giảm</label>
                  <select
                    value={discountType}
                    onChange={e => setDiscountType(e.target.value as any)}
                    className="w-full px-3 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  >
                    <option value="percent">Giảm theo %</option>
                    <option value="fixed">Giảm số tiền cố định (VNĐ)</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    {discountType === 'percent' ? 'Mức giảm (%)' : 'Số tiền giảm (VNĐ)'}
                  </label>
                  <input
                    type="number"
                    required
                    min={1}
                    value={discountValue}
                    onChange={e => setDiscountValue(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Giảm tối đa (VNĐ)</label>
                  <input
                    type="number"
                    required
                    step={5000}
                    value={maxDiscount}
                    onChange={e => setMaxDiscount(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Đơn tối thiểu (VNĐ)</label>
                  <input
                    type="number"
                    required
                    step={10000}
                    value={minOrder}
                    onChange={e => setMinOrder(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Số lượt dùng tối đa</label>
                  <input
                    type="number"
                    required
                    min={1}
                    value={usageLimit}
                    onChange={e => setUsageLimit(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Ngày hết hạn</label>
                  <input
                    type="date"
                    required
                    value={expiryDate}
                    onChange={e => setExpiryDate(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Mô tả hiển thị</label>
                <input
                  type="text"
                  placeholder="Ví dụ: Giảm 20% tối đa 50k cho khách hàng đặt xe tải..."
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
                />
              </div>

              <div className="pt-3 flex items-center justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2.5 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-blue-600 text-white hover:bg-blue-700 shadow-sm disabled:opacity-50"
                >
                  {submitting ? 'Đang lưu Cloud...' : 'Lưu & Kích hoạt'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
